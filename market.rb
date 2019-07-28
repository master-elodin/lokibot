require_relative 'cargos'

class Market
  
  def initialize(game, database)
    @game = game

    @market_table = database.get_db[:market]
    @transaction_table = database.get_db[:transaction]

    @current_cargo = {}
  end

  def all_cargo
    %w[mining, medical, narcotics, weapons, water, metal]
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
    # TODO: sell cargo if lower price differential if possible to buy higher differential if there was space

    transaction_data = {side: 'sell'}
    current_hold.each do |cargo_name, value|
      cargo_price = current_market[cargo_name]
      if value > 0 and Data.is_cargo_banned(cargo_name, @game.current_planet)
        puts "Cannot sell `#{cargo_name}` on #{@game.current_planet}"
      elsif value > 0
        is_last_turn = @game.turns_left == 1
        if Cargos.can_sell(cargo_name, cargo_price) || is_last_turn
          transaction_data[cargo_name] = value
          puts "Selling #{value} #{cargo_name} at #{cargo_price} for a total income of #{cargo_price * value} credits"

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
    possible_cargos.sort {|a, b| Cargos.price_differential(b[:cargo_name], b[:cargo_price]) <=> Cargos.price_differential(a[:cargo_name], a[:cargo_price])}
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
  end

  def buy_single_cargo(cargo_name, cargo_amt)
    cargo_price = current_market[cargo_name]
    if cargo_amt == 'max'
      cargo_amt = [(@game.current_credits / cargo_price).floor, @game.open_bays].min
    end

    if cargo_amt > @game.open_bays
      # TODO - this case should never happen; remove
      puts "Tried to buy #{cargo_amt} but only have space for #{@game.open_bays}"
      return
    end

    total_purchase_price = cargo_amt * cargo_price
    if total_purchase_price > @game.current_credits
      # TODO - this case should never happen; remove
      puts "Tried to spend #{cargo_price} but only have #{@game.current_credits}"
      return
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
    puts "Buying #{cargo_amt} #{cargo_name} at #{cargo_price} each, for a total cost of #{total_purchase_price}"

    @game.take_action('trade', {transaction: transaction_data})
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