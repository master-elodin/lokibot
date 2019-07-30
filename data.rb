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

    # TODO: remove columns
    # loanshark - loan_amt_repayed, turn_repayed
    # notifications - cargo_type
    # transaction - avg_amt_purchased, avg_amt_sold, total_amt_purchased, total_amt_sold;

    unless DB.table_exists?(:loanshark)
      DB.create_table :loanshark do
        primary_key :id
        String :game_id
        Boolean :forced_repayment
        Boolean :forced_repayment_recovered
        Integer :loan_amt_repaid
        Integer :turn_repaid
        Integer :sellable_cargo_value_at_repayment
      end
      puts 'Created new loanshark table'
    end

    unless DB.table_exists?(:score)
      DB.create_table :score do
        primary_key :id
        String :game_id
        Integer :final_score
        Boolean :unsold_cargo
        String :unsold_cargo_name
        String :final_planet
        Integer :total_bays
      end
      puts 'Created new score table'
    end

    unless DB.table_exists?(:transaction)
      DB.create_table :transaction do
        primary_key :id
        String :game_id
        String :planet # planet it was purchased on
        String :type # purchase/sale
        String :name # e.g. water, metal
        Integer :amount # amount of the cargo purchased
        Integer :price # price per cargo
        Integer :turn_number
      end
      puts 'Created new transaction table'
    end

    # record EVERY cargo on EVERY planet
    DB.create_table? :market do
      primary_key :id
      String :game_id
      String :planet
      String :name
      Integer :price
      Integer :turn_number
    end

    # summarize the cargos for a given game
    DB.create_table? :market_avg do
      primary_key :id
      String :game_id
      String :name
      Integer :price
      Integer :num_times_seen # games won't necessary last 20 turns, so record how many times it was seen
    end

    DB.create_table? :transaction_meta do
      primary_key :id
      String :name # name of cargo
      Float :avg_price # average price of cargo for every time it was seen
      Float :avg_price_purchased
      Float :avg_amt_purchased
      Float :avg_price_sold
      Float :avg_amt_sold
      Integer :num_times_seen
      Integer :num_times_purchased
      Integer :total_amt_purchased
      Integer :num_times_sold
      Integer :total_amt_sold
    end

    DB.create_table? :travel do
      primary_key :id
      String :game_id
      String :planet
      Integer :turn_number
    end

    DB.create_table? :notifications do
      primary_key :id
      String :game_id
      String :planet
      Integer :turn_number
      String :notification_type
      String :notification_text
      String :cargo_name
      Integer :cargo_price
      String :cargo_price_type
    end

    @loanshark = DB[:loanshark]
    @score = DB[:score]
    @transaction = DB[:transaction]
  end

  def get_db
    DB
  end

  def add_transaction(game_id, planet, type, name, amount, price, turn_number)
    @transaction.insert(:game_id => game_id, :planet => planet, :type => type, :name => name, :amount => amount, :price => price, :turn_number => turn_number)
  end

  def get_transaction_list(game_id)
    @transaction.where(:game_id => game_id).map([:planet, :type, :name, :amount, :price, :turn_number])
  end

  def add_final_score(game_id, final_score, unsold_cargo)
    @score.insert(:game_id => game_id,
                  :final_score => final_score,
                  :unsold_cargo => unsold_cargo,
                  :unsold_cargo_name => unsold_cargo_name,
                  :final_planet => final_planet)
  end

  def get_average_final_score
    @score.avg(:final_score).round(2)
  end

  def get_total_repayment_count
    @loanshark.count
  end

  def get_percent_forced_repayment
    forced_repayments = @loanshark.where(:forced_repayment => true)
    (((forced_repayments.count * 1.0) / (get_total_repayment_count * 1.0)) * 100.0).round(2)
  end

  def get_percent_forced_repayment_recovered
    forced_repayments_recovered = @loanshark.where(:forced_repayment_recovered => true)
    (((forced_repayments_recovered.count * 1.0) / (get_total_repayment_count * 1.0)) * 100.0).round(2)
  end

end