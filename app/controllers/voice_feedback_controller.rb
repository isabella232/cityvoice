class VoiceFeedbackController < ApplicationController

  @@app_url = "1000in1000.com"

  def route_to_survey
    if !params.has_key?("Digits") 
      response_xml = Twilio::TwiML::Response.new do |r| 
        r.Say "Hello! If you are calling about a specific property enter the property code followed by the pound sign. Otherwise enter 0."
        r.Gather :timeout => 10, :numdigits => 4
      end.text
    # Eventually replace below with lookup and validation of property code
    else
      if params["Digits"].to_s.length == 4
        session[:property_code] = params["Digits"]
        session[:survey] = "property"
      else
        session[:survey] = "neighborhood"
      end
      response_xml = Twilio::TwiML::Response.new do |r| 
        r.Redirect "voice_survey"
      end.text
    end
    render :inline => response_xml
  end

  def voice_survey
    # Set the index if none exists
    if session[:current_question_id] == nil
      @current_question = Question.find_by_short_name(Survey.questions_for("neighborhood")[0])
      session[:current_question_id] = @current_question.id
    else
      # Process data for existing question and iterate counter
      @current_question = Question.find(session[:current_question_id])
      FeedbackInput.create!(question_id: @current_question.id, neighborhood_id: 1, numerical_response: params["Digits"], phone_number: params["From"][1..-1].to_i)
      current_index = Survey.questions_for("neighborhood").index(@current_question.short_name)
      @current_question = Question.find_by_short_name(Survey.questions_for("neighborhood")[current_index+1])
      session[:current_question_id] = @current_question.id
    end
    @response_xml = Twilio::TwiML::Response.new do |r| 
      r.Say @current_question.voice_text 
      if @current_question.feedback_type == "numerical_response"
        r.Gather :timeout => 10, :numdigits => 1
      else
        # Handle the voice recording here
      end
    end.text
    render :inline => @response_xml
  end


  def splash_message 
    response_xml = Twilio::TwiML::Response.new do |r| 
      r.Say "Welcome to Auto Midnight, brought to you by Hot Snakes and Swami Records."
      r.Say "Please enter a property code, and then press the pound sign."
      r.Gather :action => "respond_to_property_code", :timeout => 10, :numdigits => 4
    end.text
    render :inline => response_xml
  end

  def respond_to_property_code
    session[:property_code] = params["Digits"]
    # Below will be replaced with property lookup
    @property_name = "1234 Fake Street"
    response_xml = Twilio::TwiML::Response.new do |r| 
      r.Say "You have entered the property at #{@property_name}."
      r.Say "What would you like to happen at this property?"
      r.Say "Press 1 for repair, 2 for remove, 3 for other. Then hit the pound sign."
      r.Gather :action => "solicit_comment", :timeout => 5, :numdigits => 1
    end.text
    render :inline => response_xml
  end

  def solicit_comment
    session[:outcome_code] = params["Digits"]
    # Abstract below out, and use in above controller method as well
    @outcome_hash = { "1" => "repair", "2" => "remove", "3" => "other" }
    # Replace with actual input cod
    @outcome_selected = @outcome_hash[params["Digits"]]
    response_xml = Twilio::TwiML::Response.new do |r| 
      r.Say "You chose #{@outcome_selected}. Please leave a voice message with your comments about this choice. You will have a one minute limit."
      # Modify below to pass to appropriate Feedback creator
      r.Record :transcribeCallback => '/voice_transcriptions', :timeout => 5
    end.text
    render :inline => response_xml
  end

=begin
    if @feedback.valid?
      reply_text = "Thanks! We recorded your response '#{@feedback.choice_selected}' for property #{@feedback.address}. You can also text comments to this number. Learn more: #{@@app_url}/#{@feedback.property_number}" 
      session[:expect_comment] = true
      session[:current_prop_num] = @feedback.property_number
      session[:failed_once?] = false
    elsif session[:expect_comment]
      reply_text = "Thanks for your comments! Your feedback will be reviewed by city staff. Please tell your neighbors about this program. Visit #{@@app_url}/#{session[:current_prop_num]}"
    elsif session[:failed_once?]
      reply_text = "We're very sorry, but we still don't understand your response. Please visit 1000in1000.com or call 123-456-7890 to submit your feedback."
    else
      reply_text = "Sorry, we didn't understand your response. Please text back one of the exact choices on the sign, like '1234O' or '1234R'."
      session[:failed_once?] = true
    end
    render :inline => TextReply.new(reply_text).body
=end

end
