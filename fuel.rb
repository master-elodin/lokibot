require_relative 'util'

class Fuel

  attr_reader :num_purchases, :total_cost

  FUEL_DEPOT_PLANET = 'pertia'
  INITIAL_PRICE = 50000

  def initialize(game)
    @game = game
    @num_purchases = 0
    @total_cost = 0
  end

  def should_visit
    # should visit even if unable to purchase, since Pertia only has metal banned and metal is lower value
    @game.current_planet != FUEL_DEPOT_PLANET and @game.turns_left < 10
  end

  def get_cost
    INITIAL_PRICE + INITIAL_PRICE * @num_purchases ** 3;
  end

  def should_buy
    # buy more fuel if the cost is less than 1/4 current credits
    @game.current_planet == FUEL_DEPOT_PLANET and get_cost < (@game.current_credits / 4.0)
  end

  def buy
    if @game.current_planet != FUEL_DEPOT_PLANET
      return
    end

    do_buy = should_buy
    cost = get_cost
    Util.log("should #{'not' unless do_buy} buy fuel for #{cost} with #{@game.current_credits} credits on board")
    if should_buy
      @game.take_action('fueldepot', {transaction: {side: 'buy', qty: 5}})

      @num_purchases += 1
      @total_cost += cost

      @game.db.get_db[:fuel_depot]
          .insert(
              :game_id => @game.id,
              :num_purchases => @num_purchases,
              :cost => cost
          )
      Util.log("Purchased fuel for #{cost}")
    end
  end
end