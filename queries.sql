-- find transactions and loan data for highest scores
select s.final_score, l.loan_amt_repaid, l.turn_repaid, t.name, t.price, t.amount, t.type
    from score s, loanshark l, "transaction" t
    where s.game_id = l.game_id and s.game_id = t.game_id
    order by s.final_score desc, t.id desc