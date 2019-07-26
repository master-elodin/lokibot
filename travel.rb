class Travel

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
    current_planet = game_data['gameState']['planet']

    # TODO: don't travel to a planet with a cargo you have that's banned unless the potential value of other non-banned cargos is greater
    # TODO: repay loanshark
    # TODO: buy more bays
    possible_planets = get_possible_travel_planets(current_planet)
    possible_planets.at(rand(possible_planets.length))
  end

  def get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]

    # don't travel to the current planet
    all_planets.delete_at(all_planets.index(current_planet))

    all_planets
  end

end