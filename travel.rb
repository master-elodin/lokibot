class Travel
  def get_turns_left(game_data)
    game_data['gameState']['turnsLeft']
  end

  def self.choose_next_planet(game_data)
    current_planet = game_data['gameState']['planet']

    # TODO: repay loanshark
    # TODO: buy more bays
    possible_planets = get_possible_travel_planets(current_planet)
    possible_planets.at(rand(possible_planets.length))
  end

  def self.get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]

    # don't travel to the current planet
    all_planets.delete_at(all_planets.index(current_planet))

    all_planets
  end

  def self.travel(game_id, to_planet)
    puts "traveling to #{to_planet}"
    data = HTTParty.post('https://skysmuggler.com/game/travel',
                         body: {gameId: game_id, toPlanet: to_planet}.to_json)
    puts "response for travel: #{data}"
    data
  end
end