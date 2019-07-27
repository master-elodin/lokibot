require 'sequel'

class Data

  def self.all_cargo
    %w[mining, medical, narcotics, weapons, water, metal]
  end

  def self.get_possible_travel_planets(current_planet)
    all_planets = %w[pertia earth taspra caliban umbriel setebos]
    all_planets.delete_at(all_planets.index(current_planet))
    all_planets
  end

  def self.is_cargo_banned(cargo, planet)
    banned_cargo = {
        'metal' => 'pertia',
        'narcotics' => 'earth',
        'medical' => 'taspra',
        'mining' => 'caliban',
        'weapons' => 'umbriel',
        'water' => 'setebos'
    }
    banned_cargo[cargo] == planet
  end
end

class DatabaseConnector

  DB = Sequel.sqlite('lokibot.db')

  def initialize

    unless DB.table_exists?(:loanshark)
      DB.create_table :loanshark do
        primary_key :id
        String :game_id
        Boolean :forced_repayment
      end
      puts 'Created new loanshark table'
    end

    unless DB.table_exists?(:score)
      DB.create_table :score do
        primary_key :id
        String :game_id
        Integer :final_score
      end
      puts 'Created new score table'
    end

    @loanshark = DB[:loanshark]
    @score = DB[:score]
  end

  def add_final_score(game_id, final_score)
    @score.insert(:game_id => game_id, :final_score => final_score)
  end

  def get_average_final_score
    @score.avg(:final_score).round(2)
  end

  def update_forced_repayment(game_id, did_force_repayment)
    @loanshark.insert(:game_id => game_id, :forced_repayment => did_force_repayment)
  end

  def get_percent_forced_repayment
    forced_repayments = 0
    total_repayments = 0
    @loanshark.map([:id, :forced_repayment]).each do |id, repayment|
      total_repayments += 1
      if repayment
        forced_repayments += 1
      end
    end
    puts "forced=#{forced_repayments} total=#{total_repayments}"
    ((forced_repayments * 1.0) / (total_repayments * 1.0)).round(2)
  end

end