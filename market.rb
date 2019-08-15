require_relative 'cargos'
require_relative 'util'

class Market

  attr_reader :max_cargo_count

  def initialize(game, database)
    @game = game

    @market_table = database.get_db[:market]
    @transaction_table = database.get_db[:transaction]

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
  end

  # sell cargo that there's no question about selling
  def sell_unambigous_cargo
    tx_log = []
    transaction_data = {side: 'sell'}
    current_hold.each do |cargo_name, cargo_amt|
      cargo_price = current_market[cargo_name]
      if cargo_amt > 0 and !Data.is_cargo_banned(cargo_name, @game.current_planet) and Cargos.can_sell(cargo_name, cargo_price)

        sell(cargo_name, cargo_amt, cargo_price, transaction_data)
        tx_log << "[#{cargo_amt} #{cargo_name} at #{cargo_price} for income of #{cargo_price * cargo_amt} credits]"
      end
    end
    if transaction_data.length > 1
      @game.take_action('trade', {transaction: transaction_data})
      Util.log("Selling unambigious cargo: #{tx_log.join(', ')}")
      true
    else
      false
    end
  end

  def sell_cargo
    Util.log("Current market: #{current_market.to_json}")
    Util.log('Selling cargo...')

    # sell non-ambiguous cargo before figuring everything else out
    did_sell_unambiguous_cargo = sell_unambigous_cargo

    credits_if_all_cargo_sold = @game.current_credits
    current_hold.each do |cargo_name, value|
      if value > 0 and !Data.is_cargo_banned(cargo_name, @game.current_planet)
        credits_if_all_cargo_sold += current_market[cargo_name] * value
      end
    end

    potential_profits = get_possible_cargos(credits_if_all_cargo_sold, false)
    if credits_if_all_cargo_sold > 0
      Util.log("Potential profits: #{potential_profits.to_json}")
    end

    transaction_data = {side: 'sell'}
    current_hold.each do |cargo_name, value|
      cargo_price = current_market[cargo_name]
      if value > 0 and Data.is_cargo_banned(cargo_name, @game.current_planet)
        Util.log("Cannot sell `#{cargo_name}` on #{@game.current_planet}")
      elsif value > 0
        if @game.current_market_low == cargo_name and @game.turns_left > 1
          Util.log("Not selling #{value} #{cargo_name} because it's at a super low price (#{cargo_price}) right now")
          next
        end

        is_last_turn = @game.turns_left == 1

        potential_profit = Cargos.get_probable_profit(cargo_name, current_market[cargo_name]) * value
        other_cargo_higher_profit = potential_profits.length > 0 && potential_profit < potential_profits[0][:profit]

        # don't sell a cargo just to buy it again
        if !is_last_turn and other_cargo_higher_profit and potential_profits[0][:name] == cargo_name
          next
        end

        # sell cargo if necessary to repay loan
        sell_to_repay_debt = (@game.current_planet == 'umbriel' and @game.current_credits < @game.loan_balance and @game.current_turn > 5)

        if is_last_turn or sell_to_repay_debt or Cargos.can_sell(cargo_name, cargo_price)
          # if last turn, sell everything regardless of price
          # or if the sale price is right, sell it
          # or if it needs to be sold to repay the loan, sell it
          sell(cargo_name, value, cargo_price, transaction_data)
          Util.log("Selling #{value} #{cargo_name} at #{cargo_price} for a total income of #{cargo_price * value} credits #{'(to repay debt)' if sell_to_repay_debt}")
        elsif other_cargo_higher_profit
          # if other cargo is higher profit, it doesn't matter if this cargo is below sell point
          sell(cargo_name, value, cargo_price, transaction_data)
          Util.log("Selling #{value} #{cargo_name} at #{cargo_price} to buy #{potential_profits[0][:name]} at #{current_market[potential_profits[0][:name]]}")
        elsif !Cargos.can_sell(cargo_name, cargo_price)
          # not last turn, not above sell point, no higher-profit cargo
          Util.log("Not selling #{value} #{cargo_name} at #{cargo_price} because it is below the `sell` price point of #{Cargos.get_price_point(cargo_name)[:sell]}")
        end
      end
    end

    # size will be 1 if only `side: sell` exists
    if transaction_data.size == 1 and !did_sell_unambiguous_cargo
      Util.log('Nothing to sell')
    else
      @game.take_action('trade', {transaction: transaction_data})
    end
  end

  def sell(cargo_name, cargo_amt, cargo_price, transaction_data)
    transaction_data[cargo_name] = cargo_amt
    record_transaction('sale', cargo_name, cargo_amt, cargo_price)
  end

  def get_possible_cargos(max_credits, use_current_market)
    possible_cargos = []
    current_market.each do |cargo_name, cargo_price|
      if cargo_price.nil?
        # banned cargo
        next
      end

      if cargo_price > max_credits
        # couldn't afford even if you wanted to
        next
      end

      unless Cargos.can_buy(cargo_name, cargo_price)
        # too expensive to buy based on buy-point
        next
      end

      if use_current_market
        # if buying, use whatever the actual current price is
        purchase_cost_per = current_market[cargo_name]
      else
        # if selling, use whatever the buy-point is
        purchase_cost_per = Cargos.get_price_point(cargo_name)[:buy]
      end

      num_can_afford = [max_credits / cargo_price, @game.open_bays].min
      profit = Cargos.get_probable_profit(cargo_name, purchase_cost_per) * num_can_afford

      if num_can_afford > 0 and profit > 0
        possible_cargos << {:name => cargo_name,
                            :price => cargo_price,
                            :num_can_afford => num_can_afford,
                            # TODO: take possible high market events into account
                            :profit => profit}
      end
    end

    # sort by price differential to get the best potential value
    possible_cargos.sort! do |a, b|
      b[:profit] <=> a[:profit]
    end
    possible_cargos
  end

  def buy_cargo
    Util.log('Buying cargo...')

    # don't over-buy
    if @game.open_bays == 0
      Util.log("No space to buy cargo")
      return
    end

    if @game.turns_left == 1
      Util.log("Not buying cargo on last turn")
      return
    end

    possible_cargos = get_possible_cargos(@game.current_credits, true)
    Util.log("Possible cargo: #{Util.add_commas(possible_cargos.to_json)}")

    # don't keep playing the game if still no cargo to buy after turn 2
    if possible_cargos.length == 0 and @game.current_credits == 20000 and @game.current_turn == 3
      Util.log("Haven't made any money after turn 3 and no cargo to buy... exiting now")
      exit 1
    end

    possible_cargos.each do |cargo|
      Util.log("#{@game.current_credits} credits left")
      if @game.current_credits >= cargo[:price] and @game.open_bays > 0
        Util.log("Going to purchase #{cargo[:name]}...")
        buy_single_cargo(cargo[:name])
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

  def buy_single_cargo(cargo_name, cargo_amt = 'max')
    cargo_price = current_market[cargo_name]
    if cargo_amt == 'max'
      cargo_amt = [(@game.current_credits / cargo_price).floor, @game.open_bays].min
    end

    unless Cargos.can_buy(cargo_name, cargo_price)
      Util.log("Not buying #{cargo_name} at #{cargo_price} because it is above buy price point of #{Cargos.get_price_point(cargo_name)[:buy]}")
      return
    end

    unless cargo_amt > 0
      Util.log("Nothing to buy")
      return
    end

    record_transaction('purchase', cargo_name, cargo_amt, cargo_price)

    transaction_data = {side: 'buy'}
    transaction_data[cargo_name] = cargo_amt
    Util.log("Buying #{cargo_amt} #{cargo_name} at #{cargo_price} each, for a total cost of #{cargo_amt * cargo_price}")

    @game.take_action('trade', {transaction: transaction_data})
  end

  def get_sellable_cargo_count
    count = 0
    current_hold.each do |name, num_onboard|
      count += num_onboard
    end
    count
  end

  def get_sellable_cargo_value
    potential_credits_from_cargo = 0
    current_hold.each do |name, num_onboard|
      unless Data.is_cargo_banned(name, @game.current_planet)
        potential_credits_from_cargo += (current_market[name] * num_onboard)
      end
    end
    potential_credits_from_cargo
  end
end