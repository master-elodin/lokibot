require_relative 'cargos'

class Shipyard

  LOT_SIZE = 25
  MIN_CREDITS_AFTER_SHIPYARD = 25000
  MAX_BAYS = 1000
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
    # visit if you can afford the bays and some cargo afterward
    potential_credits >= (SHIPYARD_COST + MIN_CREDITS_AFTER_SHIPYARD)
  end

  def buy_bays
    if @game.current_planet != SHIPYARD_PLANET
      return
    end

    # if already at max bays, can't buy any more anyway
    if @game.total_bays === MAX_BAYS
      return
    end

    num_lots = (@game.current_credits - MIN_CREDITS_AFTER_SHIPYARD) / SHIPYARD_COST
    cost = num_lots * SHIPYARD_COST * 1.0
    cost_percentage = (cost / @game.current_credits).round(2)
    until num_lots == 0 or cost_percentage <= 0.4
      # don't spend more than half your credits on shipyard
      puts "Buying #{num_lots * LOT_SIZE} for #{cost} would use #{cost_percentage}% of your #{@game.current_credits}"

      num_lots -= 1
      cost = num_lots * SHIPYARD_COST * 1.0
      cost_percentage = (cost / @game.current_credits).round(2)
    end

    if num_lots <= 0
      return
    end

    num_bays = num_lots * LOT_SIZE
    puts "Should buy #{num_bays} bays for a cost of #{cost} leaving #{@game.current_credits - cost} credits"
    @game.take_action('shipyard', {transaction: {side: 'buy', qty: num_bays}})
  end
end