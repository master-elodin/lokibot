require_relative 'cargos'
require_relative 'util'

class Market

  attr_reader :max_cargo_count
  
  def initialize(game, database)
    @game = game

    @market_table = database.get_db[:market]
    @transaction_table = database.get_db[:transaction]

    @current_cargo = {}

    @max_cargo_count = 0
  end

  def all_cargo
    %w[mining medical, narcotics, weapons, water, metal]
  end
  
  def current_market
    @game.game_data['currentMarket']
  end
  
  def current_hold
    @game.game_data['gameState']['currentHold']
  end

  def record_current_market
    current_market.each do |cargo_name, cargo_price|
      unless cargo_price.nil?
        @market_table.insert(:game_id => @game.id,
                              :planet => @game.current_planet,
                              :name => cargo_name,
                              :price => cargo_price,
                              :turn_number => @game.current_turn)
      end
    end
  end

  def record_transaction(type, name, amount, price)
    @transaction_table.insert(:game_id => @game.id,
                              :planet => @game.current_planet,
                              :type => type,
                              :name => name,
                              :amount => amount,
                              :price => price,
                              :turn_number => @game.current_turn)
    if type == 'purchase'
      @current_cargo[name] = amount
    else
      @current_cargo[name] = 0
    end
  end

  def sell_cargo
    puts 'Selling cargo...'

    price_differentials = []
    potential_credits = @game.current_credits
    current_hold.each do |cargo_name, value|
      if value > 0 and !Data.is_cargo_banned(cargo_name, @game.current_planet)
        potential_credits += current_market[cargo_name]
      end
    end

    current_market.each do |cargo_name, cargo_price|
      # add differential for any cargo that can be bought on current planet AND you can afford
      if !cargo_price.nil? and potential_credits >= cargo_price and Cargos.can_buy(cargo_name, cargo_price)
        price_differentials << {name: cargo_name, profit: Cargos.price_differential(cargo_name, cargo_price)}
      end
    end
    price_differentials.sort! do |a, b|
      b[:profit] <=> a[:profit]
    end

    transaction_data = {side: 'sell'}
    current_hold.each do |cargo_name, value|
      cargo_price = current_market[cargo_name]
      if value > 0 and Data.is_cargo_banned(cargo_name, @game.current_planet)
        puts "Cannot sell `#{cargo_name}` on #{@game.current_planet}"
      elsif value > 0
        if @game.current_market_low == cargo_name
          puts "Not selling #{value} #{cargo_name} because it's at a super low price (#{cargo_price}) right now"
          next
        end

        is_last_turn = @game.turns_left == 1

        potential_profit = Cargos.price_differential(cargo_name, cargo_price)
        other_cargo_higher_profit = price_differentials.length > 0 && potential_profit < price_differentials[0][:profit]

        if Cargos.can_sell(cargo_name, cargo_price) || is_last_turn || other_cargo_higher_profit
          transaction_data[cargo_name] = value

          if other_cargo_higher_profit and !is_last_turn
            puts "Selling #{value} #{cargo_name} at #{cargo_price} to buy #{price_differentials[0][:name]} at #{current_market[price_differentials[0][:name]]}"
          else
            puts "Selling #{value} #{cargo_name} at #{cargo_price} for a total income of #{Util.add_commas(cargo_price * value)} credits"
          end

          record_transaction('sale', cargo_name, value, cargo_price)
        else
          puts "Not selling #{cargo_name} at #{cargo_price} because it is below the `sell` price point of #{Cargos.get_price_point(cargo_name)[:sell]}"
        end
      end
    end

    # size will be 1 if only `side: sell` exists
    if transaction_data.size == 1
      puts 'Nothing to sell'
    else
      @game.take_action('trade', {transaction: transaction_data})
    end
  end

  def get_possible_cargos
    possible_cargos = []
    current_market.each do |cargo_name, cargo_price|
      unless cargo_price.nil?
        is_within_price_point = Cargos.can_buy(cargo_name, cargo_price)
        can_afford = cargo_price <= @game.current_credits

        if !Data.is_cargo_banned(cargo_name, @game.current_planet) and is_within_price_point and can_afford
          possible_cargos << {:cargo_name => cargo_name, :cargo_price => cargo_price}
        end
      end
    end

    # sort by price differential to get the best potential value
    possible_cargos.sort! do |a, b|
      Cargos.price_differential(b[:cargo_name], b[:cargo_price]) <=> Cargos.price_differential(a[:cargo_name], a[:cargo_price])
    end
    possible_cargos
  end

  def buy_cargo
    puts 'Buying cargo...'

    # don't over-buy
    if @game.open_bays == 0
      puts "No space to buy cargo"
      return
    end

    if @game.turns_left == 1
      puts "Not buying cargo on last turn"
      return
    end

    possible_cargos = get_possible_cargos
    puts "Possible cargo: #{possible_cargos}"

    possible_cargos.each do |cargo|
      puts "#{@game.current_credits} credits left"
      if @game.current_credits >= cargo[:cargo_price] and @game.open_bays > 0
        puts "Going to purchase #{cargo[:cargo_name]}..."
        buy_single_cargo(cargo[:cargo_name], 'max')
      else
        break
      end
    end

    hold_size = 0
    current_hold.each do |name, amt|
      hold_size += amt
    end
    @max_cargo_count = [hold_size, @max_cargo_count].max
  end

  def buy_single_cargo(cargo_name, cargo_amt)
    cargo_price = current_market[cargo_name]
    if cargo_amt == 'max'
      cargo_amt = [(@game.current_credits / cargo_price).floor, @game.open_bays].min
    end

    unless Cargos.can_buy(cargo_name, cargo_price)
      puts "Not buying #{cargo_name} at #{cargo_price} because it is above buy price point of #{Cargos.get_price_point(cargo_name)[:buy]}"
      return
    end

    unless cargo_amt > 0
      puts "Nothing to buy"
      return
    end

    record_transaction('purchase', cargo_name, cargo_amt, cargo_price)

    transaction_data = {side: 'buy'}
    transaction_data[cargo_name] = cargo_amt
    puts "Buying #{cargo_amt} #{cargo_name} at #{cargo_price} each, for a total cost of #{cargo_amt * cargo_price}"

    @game.take_action('trade', {transaction: transaction_data})
  end

  def get_sellable_cargo_count
    count = 0
    @current_cargo.each do |name, num_onboard|
      count += num_onboard
    end
    count
  end

  def get_sellable_cargo_value
    potential_credits_from_cargo = 0
    @current_cargo.each do |name, num_onboard|
      unless Data.is_cargo_banned(name, @game.current_planet)
        potential_credits_from_cargo += (current_market[name] * num_onboard)
      end
    end
    puts "You have #{potential_credits_from_cargo} credits of sellable cargo"
    potential_credits_from_cargo
  end
end