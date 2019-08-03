require_relative 'shipyard'

class Travel

  LOAN_SHARK_PLANET = 'umbriel'
  SHIPYARD_PLANET = 'taspra'
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

    if to_planet.length == 0
      puts "Empty to_planet. current_planet=#{@game.current_planet}, possible_planets=#{get_possible_travel_planets(@game.current_planet)}"
      exit 1
    end

    puts "Traveling to #{to_planet}"
    @game.take_action('travel', {toPlanet: to_planet})

    @database.get_db[:travel].insert(:game_id => @game.id,
                                     :planet => @game.current_planet,
                                     :turn_number => @game.current_turn)
  end

  def choose_next_planet
    # TODO: don't travel to loan shark immediately if other things might be better

    if @game.loan_shark.can_repay(true)
      puts "Can repay debt of #{@game.loan_balance} - traveling to #{LOAN_SHARK_PLANET}"
      return LOAN_SHARK_PLANET
    end

    # TODO: don't always visit shipyard if there are high value cargos to sell
    if @game.shipyard.should_visit
      return SHIPYARD_PLANET
    end

    possible_planets = get_possible_travel_planets(@game.current_planet).sort do |a, b|
      Cargos.possible_cargo_value(@game, b) <=> Cargos.possible_cargo_value(@game, a)
    end

    highest_value = 0
    possible_planets = possible_planets.select do |planet|
      possible_value = Cargos.possible_cargo_value(@game, planet)
      if possible_value > highest_value
        # since possible_planets are now sorted in descending order based on possible cargo value,
        # highest_value should only be reassigned once for the highest value
        highest_value = possible_value
      end
      possible_value >= highest_value
    end

    # don't go to Umbriel after loan repaid because weapons are banned there
    if @game.loan_balance == 0 and !possible_planets.index('umbriel').nil?
      possible_planets.delete_at(possible_planets.index('umbriel'))
    end

    # don't travel to earth unless you want to bank
    # TODO: when implementing banking, change here
    unless possible_planets.index('earth').nil?
      possible_planets.delete_at(possible_planets.index('earth'))
    end

    possible_planets.at(rand(possible_planets.length - 1))
  end

  def get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]

    # don't travel to the current planet
    all_planets.delete_at(all_planets.index(current_planet))

    all_planets
  end
end