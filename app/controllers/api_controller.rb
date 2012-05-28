class ApiController < ApplicationController
    before_filter :check_api_key
    
    def show_request
        @request = InfoRequest.find(params[:id])
        raise PermissionDenied if @request.public_body_id != @public_body.id
        
        @request_data = {
            :id => @request.id,
            :url => make_url("request", @request.url_title),
            :title => @request.title,
            
            :created_at => @request.created_at,
            :updated_at => @request.updated_at,
            
            :status => @request.calculate_status,
            
            :public_body_url => make_url("body", @request.public_body.url_name),
            :requestor_url => make_url("user", @request.user.url_name),
            :request_email => @request.incoming_email,
            
            :request_text => @request.last_event_forming_initial_request.outgoing_message.body,
        }
        
        render :json => @request_data
    end
    
    def create_request
        json = ActiveSupport::JSON.decode(params[:request_json])
        request = InfoRequest.new(
            :title => json["title"],
            :public_body_id => @public_body.id,
            :described_state => "waiting_response",
            :external_user_name => json["external_user_name"],
            :external_url => json["external_url"]
        )
        
        outgoing_message = OutgoingMessage.new(
            :status => 'ready',
            :message_type => 'initial_request',
            :body => json["body"],
            :last_sent_at => Time.now(),
            :what_doing => 'normal_sort',
            :info_request => request
        )
        request.outgoing_messages << outgoing_message
        
        # Return an error if the request is invalid
        if !request.valid?
            # We don't want the error "Outgoing messages is invalid", as in this
            # case the list of errors will also contain a more specific error
            # describing the reason it is invalid.
            info_request.errors.delete("outgoing_messages")
            
            render :json => {
                'errors' => request.errors.full_messages
            }
            return
        end
        
        request.save!
        request.log_event("sent",
            :email => nil,
            :outgoing_message_id => outgoing_message.id,
            :smtp_message_id => nil
        )
        render :json => {
            'url' => make_url("request", request.url_title),
            'id'  => request.id
        }
        
    end
    
    def add_correspondence
        
    end
    
    protected
    def check_api_key
        @public_body = PublicBody.find_by_api_key(params[:k].gsub(' ', '+'))
        raise PermissionDenied if @public_body.nil?
    end
    
    private
    def make_url(*args)
        "http://" + MySociety::Config.get("DOMAIN", '127.0.0.1:3000') + "/" + args.join("/")
    end
end