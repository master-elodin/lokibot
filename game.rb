require_relative 'market'
require_relative 'travel'

LOAN_SHARK_PLANET = 'umbriel'
MIN_CREDITS_AFTER_REPAYMENT = 10000

class Game

  attr_reader :id, :game_data, :market, :db

  def initialize(database)
    puts 'Starting new game...'
    game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response

    @game_data = game_data
    @id = game_data['gameId']

    @market = Market.new(self, database)
    @travel = Travel.new(self, database)

    @db = database
  end

  def travel
    @travel.travel
  end

  def take_action(relative_url, body)
    body[:gameId] = @id
    @game_data = HTTParty.post("https://skysmuggler.com/game/#{relative_url}", body: body.to_json)
  end

  def game_state
    @game_data['gameState']
  end

  def current_planet
    game_state['planet']
  end

  def current_credits
    game_state['credits']
  end

  def current_turn
    20 - turns_left
  end

  def turns_left
    game_state['turnsLeft']
  end

  # -- bays
  def total_bays
    game_state['totalBays']
  end

  def used_bays
    game_state['usedBays']
  end

  def open_bays
    total_bays - used_bays
  end
  # -- end bays

  # -- loan shark
  def loan_balance
    game_state['loanBalance']
  end
  
  def repay_loanshark
    loan_amt_start_turn = loan_balance
    credits_after_repayment = current_credits - loan_amt_start_turn

    if loan_amt_start_turn > 0 and current_planet == LOAN_SHARK_PLANET and credits_after_repayment > MIN_CREDITS_AFTER_REPAYMENT
      puts "Repaying loan of #{loan_amt_start_turn}, leaving balance of #{credits_after_repayment}"
      take_action('loanshark', {transaction: {qty: loan_amt_start_turn, side: "repay"}})

      @db.get_db[:loanshark].insert(:game_id => @id,
                                    :forced_repayment => false,
                                    :forced_repayment_recovered => false,
                                    :loan_amt_repaid => loan_amt_start_turn,
                                    :turn_repaid => current_turn)
    end
  end
  # -- end loan shark
end