class Travel

  LOAN_SHARK_PLANET = 'umbriel'
  MIN_CREDITS_AFTER_REPAYMENT = 10000

  def initialize
    @planets_traveled_to = []
  end

  def get_planets_traveled_to
    @planets_traveled_to
  end

  def travel(game_data)
    game_id = game_data['gameId']
    to_planet = choose_next_planet(game_data)

    @planets_traveled_to << to_planet

    puts "traveling to #{to_planet}"
    HTTParty.post('https://skysmuggler.com/game/travel', body: {gameId: game_id, toPlanet: to_planet}.to_json)
  end

  def choose_next_planet(game_data)
    game_state = game_data['gameState']
    current_planet = game_state['planet']

    credits_after_repayment = game_state['credits'] - game_state['loanBalance']
    if game_state['loanBalance'] > 0 and current_planet != LOAN_SHARK_PLANET and credits_after_repayment > MIN_CREDITS_AFTER_REPAYMENT
      puts "Can repay debt of #{game_state['loanBalance']} - traveling to #{LOAN_SHARK_PLANET}"
      # TODO: only repay loanshark with a possibility of purchasing cargo afterward
      return LOAN_SHARK_PLANET
    end

    # TODO: buy more bays

    # don't travel to a planet with a cargo you have that's banned unless the potential value of other non-banned cargos is greater
    possible_planets = []
    get_possible_travel_planets(current_planet).each do |planet|
      have_banned_cargo = false
      game_state['currentHold'].each do |cargo_name, cargo_amt|
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