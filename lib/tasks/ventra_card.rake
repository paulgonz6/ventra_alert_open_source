namespace :ventra_card do

  desc "check balance of ventra card and send alert if too low"

  task check_balance: :environment do
    @twilio = Twilio::REST::Client.new ENV['twilio_account_sid'], ENV['twilio_auth_token']

    conn = Faraday.new(:url => 'https://www.ventrachicago.com/') do |faraday|
      faraday.use      :cookie_jar
      faraday.request  :url_encoded             # form-encode POST params
      faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    response_get = conn.get do |req|
      req.url 'balance/'
      req.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.124 Safari/537.36'
    end

    parsed_html = Nokogiri::HTML(response_get.body)

    request_token = parsed_html.css("#hdnRequestVerificationToken").attribute("value").value

    response_post = conn.post do |req|
      req.url 'ajax/NAM.asmx/CheckAccountBalance'
      req.headers['Content-Type'] = 'application/json'
      req.headers['RequestVerificationToken'] = request_token
      req.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.124 Safari/537.36'
      req.headers['X-Requested-With'] = 'XMLHttpRequest'
      req.body = "{'TransitMediaInfo':{'SerialNumber':#{ENV['ventra_serial_number']},
      'ExpireMonth':#{ENV['expire_month']},'ExpireYear':#{ENV['expire_year']}},
      's':1,'IncludePassSupportsTal':true}"
    end

    parsed_html_post = Nokogiri::HTML(response_post.body)

    @balance = parsed_html_post.children.children.children.children.text.split(/:|,/)[17].gsub(/[^\w]/,'').to_i/100.0

    @level = ENV['alert_level'].to_f

    if @balance < @level
      @twilio.messages.create(
        from: ENV['twilio_phone_number'],
        to: ENV['phone_number'],
        body: "Hey there, just wanted to let you know your Ventra Balance is now $#{@balance}"
        )
    end

  end

end
