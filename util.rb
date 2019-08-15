class Util

  LOG_ALL = true
  @log_statements = []

  def self.print
    @log_statements.each(&method(:puts))
  end

  def self.add_newline
    self.log('')
  end

  def self.log(text)
    log = self.add_commas(text)
    @log_statements << log
    if LOG_ALL
      puts log
    end
  end

  def self.add_commas(text)
    text = text.to_s
    if text.index(/[a-zA-Z]+/).nil?
      # if no letters, just add commas to the number
      text.reverse.scan(/\d{3}|.+/).join(",").reverse.gsub(/-,/, '-')
    else
      # if given text is a string, add commas to each number
      text.gsub(/\d+/) {|n| self.add_commas(n)}
    end
  end
end