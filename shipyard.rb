class Shipyard

  SHIPYARD_COST = 25000

  def self.should_visit(game)


    # if you can't afford a new bay, don't visit
    if game.current_credits < SHIPYARD_COST
      return
    end

  end
end