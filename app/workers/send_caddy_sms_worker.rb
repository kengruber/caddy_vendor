class SendCaddySmsWorker
  include Sidekiq::Worker

  def perform(to, caddy_id, customer_id, message_body)
    client = Savon.client(wsdl: "#{ENV['EZCASH_WSDL_URL']}")
    client.call(:send_sms, message: { Phone: to, Msg: message_body})
    SmsMessage.create(to: to, customer_id: customer_id, caddy_id: caddy_id, body: message_body)
  end
  
end
