class Util

  def self.add_commas(text)
    if text.index(/\w+/).nil?
      # if no letters, just add commas to the number
      text.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse.gsub(/-,/, '-')
    else
      # if given text is a string, add commas to each number
      text.gsub(/\d+/) {|n| self.add_commas(n)}
    end
  end
end