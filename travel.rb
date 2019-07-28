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

    # TODO: don't travel to a planet with a cargo you have that's banned unless the potential value of other non-banned cargos is greater
    possible_planets = []
    get_possible_travel_planets(@game.current_planet).each do |planet|
      have_banned_cargo = false
      @game.game_state['currentHold'].each do |cargo_name, cargo_amt|
        if cargo_amt > 0 and Data.is_cargo_banned(cargo_name, planet)
          have_banned_cargo = true
          puts "Avoiding #{planet} because #{cargo_name} is banned there"
          break
        end
      end

      unless have_banned_cargo
        possible_planets << planet
      end
    end

    possible_planets.at(rand(possible_planets.length))
  end

  def get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]

    # don't travel to the current planet
    all_planets.delete_at(all_planets.index(current_planet))

    all_planets
  end

end