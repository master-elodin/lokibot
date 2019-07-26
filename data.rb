# frozen_string_literal: true

class Data

  def self.all_cargo
    %w[mining, medical, narcotics, weapons, water, metal]
  end

  def self.get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]
    all_planets.delete_at(all_planets.index(current_planet))
    all_planets
  end

  banned_cargo = {
    "metal": 'pertia',
    "narcotics": 'earth',
    "medical": 'taspra',
    "mining": 'caliban',
    "weapons": 'umbriel',
    "water": 'setebos'
  }
end
