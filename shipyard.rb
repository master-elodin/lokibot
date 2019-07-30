require_relative 'cargos'

class Shipyard

  # TODO: average out hold utilization like was done for cargo prices
  HOLD_UTILIZATION_RATIO = 50
  LOT_SIZE = 25
  MAX_BAYS = 1000
  MAX_PURCHASE_ONE_TIME = 100
  MIN_CREDITS_AFTER_SHIPYARD = 25000
  MIN_TURNS_LEFT = 3
  PURCHASE_COST_RATIO = 0.3
  SHIPYARD_COST = 20000
  SHIPYARD_PLANET = 'taspra'

  def initialize(game, database)
    @game = game
    @database = database
  end

  def should_visit

    # if already at max bays, can't buy any more anyway
    if @game.total_bays === MAX_BAYS
      return
    end

    # if already on taspra, no need to travel there
    if @game.current_planet == SHIPYARD_PLANET
      return
    end

    potential_credits = @game.current_credits + Cargos.possible_cargo_value(@game, SHIPYARD_PLANET)
    # visit if you can afford the bays (and should buy them) and some cargo afterward
    get_num_bays_to_buy > 0 && potential_credits >= (SHIPYARD_COST + MIN_CREDITS_AFTER_SHIPYARD)
  end

  def get_num_bays_to_buy
    # make sure enough turns are left to be worth it
    # but still buy if there's a low price market event
    if @game.turns_left < MIN_TURNS_LEFT and @game.current_market_low.length == 0
      return 0
    end

    # if you can't afford it, don't bother
    if @game.current_credits < SHIPYARD_COST + MIN_CREDITS_AFTER_SHIPYARD
      return 0
    end

    # if more than X bays already, don't buy more unless they can be filled
    num_theoretical_bays_open = @game.open_bays
    num_theoretical_credits = @game.current_credits
    num_possible_cargos = @game.market.get_sellable_cargo_count
    @game.market.get_possible_cargos.each do |cargo|
      if num_theoretical_credits >= cargo[:cargo_price] and num_theoretical_bays_open > 0 and num_theoretical_credits > 0
        num_can_afford = [(num_theoretical_credits / cargo[:cargo_price]).floor, num_theoretical_bays_open].min

        num_possible_cargos += num_can_afford
        num_theoretical_bays_open -= num_can_afford
        num_theoretical_credits -= num_can_afford * cargo[:cargo_price]
      end
    end
    potential_hold_utilization = get_hold_utilization(@game.total_bays, num_possible_cargos)
    if potential_hold_utilization < HOLD_UTILIZATION_RATIO
      puts "Not buying more cargo because #{num_possible_cargos} possible cargos (including cargo already on abord) to buy will only fill #{potential_hold_utilization}% of the existing #{@game.total_bays} bays"
      return 0
    end

    num_lots = (@game.current_credits - MIN_CREDITS_AFTER_SHIPYARD) / SHIPYARD_COST

    # first time buying, don't worry about percentage or utilization
    if num_lots == 1 and @game.total_bays == 25
      return num_lots * LOT_SIZE
    end

    # make sure that current bays are already being utilized except for first time
    current_hold_utilization = get_hold_utilization(@game.total_bays)
    if current_hold_utilization < HOLD_UTILIZATION_RATIO and @game.total_bays == 25
      puts "Not buying more bays because hold utilization is only #{current_hold_utilization}% of #{@game.total_bays} total bays"
      return 0
    end

    # don't spend more than X% your credits on shipyard unless it's the first time buying them
    until num_lots <= 0
      if get_cost_percentage(num_lots) <= PURCHASE_COST_RATIO
        break
      end

      proposed_utilization = get_hold_utilization(@game.total_bays + (num_lots * LOT_SIZE))
      if proposed_utilization >= HOLD_UTILIZATION_RATIO
        puts "Potential purchase utilization: #{proposed_utilization}% if buying #{num_lots * LOT_SIZE} more bays for a total of #{@game.total_bays + (num_lots * LOT_SIZE)}"
        break
      end
      # TODO: if low price market event, buy enough bays that all of them will be able to be filled
      num_lots -= 1
    end
    [num_lots * LOT_SIZE, MAX_PURCHASE_ONE_TIME].min
  end

  def get_hold_utilization(num_bays, cargo_count = @game.market.max_cargo_count)
    ((cargo_count / (num_bays * 1.0)).round(2) * 100).round(2)
  end

  def get_cost_percentage(num_lots)
    ((num_lots * SHIPYARD_COST * 1.0) / @game.current_credits).round(2)
  end

  def buy_bays
    if @game.current_planet != SHIPYARD_PLANET
      return
    end

    # if already at max bays, can't buy any more anyway
    if @game.total_bays === MAX_BAYS
      return
    end

    num_bays = get_num_bays_to_buy
    if num_bays <= 0
      return
    end

    cost = (num_bays / LOT_SIZE) * SHIPYARD_COST
    puts "Should buy #{num_bays} bays for a cost of #{cost} leaving #{@game.current_credits - cost} credits"
    @game.take_action('shipyard', {transaction: {side: 'buy', qty: num_bays}})
  end
end