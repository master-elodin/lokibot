class Travel
  def get_turns_left(game_data)
    game_data['gameState']['turnsLeft']
  end

  def self.choose_next_planet(current_planet)
    possible_planets = Data.get_possible_travel_planets(current_planet)
    possible_planets.at(rand(possible_planets.length))
  end

  def travel(game_id, to_planet)
    puts "traveling to #{to_planet}"
    HTTParty.post('https://skysmuggler.com/game/travel',
                  body: { gameId: game_id, toPlanet: to_planet }.to_json)
  end
end