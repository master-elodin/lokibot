class Travel

  LOAN_SHARK_PLANET = 'umbriel'
  MIN_CREDITS_AFTER_REPAYMENT = 10000

  def initialize(game, database)
    @game = game
    @database = database
  end

  def travel
    if @game.turns_left == 1
      puts "Not traveling on last turn"
      return
    end

    to_planet = choose_next_planet

    puts "traveling to #{to_planet}"
    @game.take_action('travel', {toPlanet: to_planet})

    @database.get_db[:travel].insert(:game_id => @game.id,
                                     :planet => @game.current_planet,
                                     :turn_number => @game.current_turn)
  end

  def choose_next_planet
    credits_after_repayment = @game.current_credits - @game.loan_balance
    if @game.loan_balance > 0 and @game.current_planet != LOAN_SHARK_PLANET and credits_after_repayment > MIN_CREDITS_AFTER_REPAYMENT
      puts "Can repay debt of #{@game.loan_balance} - traveling to #{LOAN_SHARK_PLANET}"
      return LOAN_SHARK_PLANET
    end

    # TODO: buy more bays

    possible_planets = get_possible_travel_planets(@game.current_planet).sort do |a, b|
      possible_cargo_value(b) <=> possible_cargo_value(a)
    end

    highest_value = 0
    possible_planets = possible_planets.select do |planet|
      possible_value = possible_cargo_value(planet)
      if possible_value > highest_value
        # since possible_planets are now sorted in descending order based on possible cargo value,
        # highest_value should only be reassigned once for the highest value
        highest_value = possible_value
      end
      possible_value >= highest_value
    end

    possible_planets.at(rand(possible_planets.length))
  end

  def get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]

    # don't travel to the current planet
    all_planets.delete_at(all_planets.index(current_planet))

    all_planets
  end

  def possible_cargo_value(planet_name)
    possible_value = 0
    @game.game_state['currentHold'].each do |cargo_name, cargo_amt|
      # don't count value of cargo if it's banned on the potential planet
      unless Data.is_cargo_banned(cargo_name, planet_name)
        possible_value += cargo_amt * Cargos.price_differential(cargo_name, Cargos.get_price_point(cargo_name)[:buy])
      end
    end
    possible_value
  end

end