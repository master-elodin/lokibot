require_relative 'cargos'

LOAN_SHARK_PLANET = 'umbriel'
MIN_CREDITS_AFTER_REPAYMENT = 40000

class Loanshark

  def initialize(game)
    @game = game
  end

  def can_repay(is_for_travel)
    # if loan balance is 0, no need to repay
    if @game.loan_balance == 0
      return false
    end

    # if not checking for Travel purposes and not on Umbriel, can't repay
    # or if checking for Travel purposes and ON Umbriel, can't travel there
    if (!is_for_travel and @game.current_planet != LOAN_SHARK_PLANET) or (is_for_travel and @game.current_planet == LOAN_SHARK_PLANET)
      return false
    end

    potential_cargo_value = Cargos.possible_cargo_value(@game, LOAN_SHARK_PLANET)
    credits_after_repayment = @game.current_credits - @game.loan_balance + potential_cargo_value
    min_credits_requirement_met = credits_after_repayment > MIN_CREDITS_AFTER_REPAYMENT

    unless min_credits_requirement_met
      return false
    end

    # if already on umbriel, make sure you have enough actual credits on hand to repay loan
    is_for_travel or @game.current_credits - @game.loan_balance > 0
  end

  def repay_loanshark
    if can_repay(false)
      loan_amt_start_turn = @game.loan_balance
      credits_after_repayment = @game.current_credits - loan_amt_start_turn + @game.market.get_sellable_cargo_value

      puts "Repaying loan of #{loan_amt_start_turn}, leaving balance of #{credits_after_repayment}"
      @game.take_action('loanshark', {transaction: {qty: loan_amt_start_turn, side: "repay"}})

      @game.db.get_db[:loanshark].insert(:game_id => @id,
                                    :forced_repayment => false,
                                    :forced_repayment_recovered => false,
                                    :loan_amt_repaid => loan_amt_start_turn,
                                    :turn_repaid => @game.current_turn)
    end
  end
end