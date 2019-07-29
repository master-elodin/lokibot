require_relative 'cargos'
require_relative 'market'
require_relative 'travel'

LOAN_SHARK_PLANET = 'umbriel'
MIN_CREDITS_AFTER_REPAYMENT = 10000

class Game

  attr_reader :id, :game_data, :market, :db, :current_market_low, :current_market_high

  def initialize(database)
    puts 'Starting new game...'
    game_data = HTTParty.get('https://skysmuggler.com/game/new_game').parsed_response

    @game_data = game_data
    @id = game_data['gameId']

    @market = Market.new(self, database)
    @travel = Travel.new(self, database)

    @db = database

    @num_pirates = 0
    @num_authorities = 0

    @current_market_low = ''
    @current_market_high = ''

    # save notifications AFTER new game is started and `@game_data` is set
    save_notifications
  end

  def travel
    @travel.travel
  end

  def take_action(relative_url, body)
    turns_left_at_start = turns_left
    body[:gameId] = @id
    @game_data = HTTParty.post("https://skysmuggler.com/game/#{relative_url}", body: body.to_json)

    # if turns are different, travel happened and notifications may be different
    if turns_left_at_start != turns_left
      @current_market_low = ''
      @current_market_high = ''
      save_notifications
    end
  end

  def save_notifications
    unless get_notifications.nil?
      get_notifications.each do |notification|
        puts "Notification: #{notification}"

        cargo_name = ''
        cargo_price = nil
        cargo_price_type = ''

        message = notification['message']

        if notification['title'] == "You've been boarded!"
          if !message.index('pirates').nil?
            @num_pirates += 1
          else
            @num_authorities += 1
          end
        elsif notification['title'] == 'Economic instability!'
          Cargos.cargo_names.each do |name|
            unless message.downcase.index(name).nil?
              cargo_name = name
              break
            end
          end

          cargo_price = @game_data['currentMarket'][cargo_name]
          if cargo_price < Cargos.get_price_point(cargo_name)[:buy]
            cargo_price_type = 'low'
            @current_market_low = cargo_name
          else
            @current_market_high = cargo_name
            cargo_price_type = 'high'
          end
        end

        @db.get_db[:notifications].insert(:game_id => @id,
                                          :planet => current_planet,
                                          :turn_number => current_turn,
                                          :notification_type => notification['titleType'],
                                          :notification_text => message,
                                          :cargo_type => cargo_name,
                                          :cargo_price => cargo_price,
                                          :cargo_price_type => cargo_price_type)
      end
    end
  end

  def get_notifications
    @game_data['notifications']
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
    (20 - turns_left) + 1
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

  def loan_shark_attacked
    attacked = false
    get_notifications.each do |notification|
      if notification['title'] == 'Ouch!'
        attacked = true
      end
    end
    attacked
  end
  # -- end loan shark
end