class Util

  def self.add_commas(number)
    # TODO: sometimes formats weirdly like this:
    # Average total score: 228,519 [this game: -,201,907]
    formatted = number.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse
    if formatted[0] == ','
      formatted[1..formatted.length-1]
    else
      formatted
    end
  end
end