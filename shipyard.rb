require_relative 'cargos'

class Shipyard

  LOT_SIZE = 25
  MIN_CREDITS_AFTER_SHIPYARD = 25000
  MAX_BAYS = 1000
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
    num_lots = (@game.current_credits - MIN_CREDITS_AFTER_SHIPYARD) / SHIPYARD_COST
    # don't spend more than X% your credits on shipyard unless it's the first time buying them
    until num_lots <= 0 or get_cost_percentage(num_lots) <= PURCHASE_COST_RATIO or (num_lots == 1 and @game.total_bays == 25)
      num_lots -= 1
    end
    num_lots * LOT_SIZE
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