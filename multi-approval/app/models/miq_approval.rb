class MiqApproval < ActiveRecord::Base
  belongs_to :approver, :polymorphic => true
  belongs_to :stamper,  :class_name => "User"
  belongs_to :miq_request

  include ReportableMixin

  default_value_for :state, "pending"

  def approver=(approver)
    super
    self.approver_name = approver.try(:name)
  end

  # def approve(userid, reason)
  #   user = userid.kind_of?(User) ? userid : User.find_by_userid(userid)
  #   raise "not authorized" unless authorized?(user)
  #   update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)

  #   # execute parent now that request is approved
  #   _log.info("Request: [#{miq_request.description}] has been approved by [#{user.userid}]")
  #   begin
  #     miq_request.approval_approved
  #   rescue => err
  #     _log.warn("#{err.message}, attempting to approve request: [#{miq_request.description}]")
  #   end
  # end

  ####### start

  def approve(userid, reason)
    user = userid.kind_of?(User) ? userid : User.find_by_userid(userid)
    raise "not authorized" unless authorized?(user)

    _log.info("Approval reason: [#{reason}]")
    _log.info("miq_request.miq_approvals.size: [#{miq_request.miq_approvals.size}]")

    if miq_request.miq_approvals.size == 1
      # Make sure still behaves like before
      _log.info("Request: OOTB approval")
      # miq_request.miq_approvals.first.update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => 'default', :stamped_on => Time.now.utc)
      miq_request.miq_approvals.first.update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)

    else
      _log.info("Request: Multi-level approval")
      _log.info("Request: [#{miq_request.description}] miq_approvals count [#{miq_request.miq_approvals.count}]\n")

      miq_request.miq_approvals.order(:id).each do |a|
      # miq_request.miq_approvals.each do |a|
        _log.info("Request: user.name '#{user.name}' stamper_name '#{a.stamper_name}' state '#{a.state}'")

        if a.stamper_name == user.name && a.state == "approved"
          _log.info("Request: [#{miq_request.description}] has already been approved by [#{user.userid}]")
          return
        end

        next if a.state == "approved"

        # Auto-approve the default
        if a.stamper_name == 'default'
          _log.info("BEFORE: stamper_name 'default' state '#{a.state}'")
          a.update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => 'default', :stamped_on => Time.now.utc)
          # a.update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)
          _log.info("AFTER:  stamper_name 'default' state '#{a.state}'")
          next
        end

        if a.stamper_name == user.name
          _log.info("BEFORE: stamper_name '#{a.stamper_name}' state '#{a.state}'")
          a.update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)
          _log.info("AFTER:  stamper_name '#{a.stamper_name}' state '#{a.state}'")
          _log.info("Request: [#{miq_request.description}] has been approved by [#{user.userid}]")

          # Update the mmessage
          miq_request_message = miq_request.message.strip
          _log.info("Request message: [#{miq_request_message}]")
          miq_request_message = miq_request_message.gsub(user.name, '')
          miq_request_message += " (Approved by: #{user.name})"
          _log.info("Request message: [#{miq_request_message}]")
          # miq_request.user_message = miq_request_message
          miq_request.resource.user_message = miq_request_message
          # miq_request.resource.set_message(miq_request_message)

          # # Auto-approve the default
          # miq_request.miq_approvals.order(:id).first.update_attribute(:state, 'approved')
          # miq_request.miq_approvals.order(:id).first.update_attribute(:reason, reason)
          # miq_request.miq_approvals.order(:id).first.update_attribute(:stamper, user)
          # miq_request.miq_approvals.order(:id).first.update_attribute(:stamper_name, 'default')
          # miq_request.miq_approvals.order(:id).first.update_attribute(:stamped_on, Time.now.utc)
          break
        end
      end
    end

    # if miq_request.approved?
    #   # execute parent now that request is approved by all
    #   _log.info("Request: [#{miq_request.description}] has been approved by all")
    #   begin
    #     miq_request.approval_approved
    #   rescue => err
    #     _log.warn("#{err.message}, attempting to approve request: [#{miq_request.description}]")
    #   end

    # else
    #   _log.info("Outstanding approvals")
    #   _log.info("miq_request.miq_approvals.size: [#{miq_request.miq_approvals.size}]")
    #   miq_request.miq_approvals.order(:id).each do |a|
    #     _log.info("Request: user.name '#{user.name}' stamper_name '#{a.stamper_name}' state '#{a.state}'")
    #   end
    # end

    begin
      miq_request.approval_approved
    rescue => err
      _log.warn("#{err.message}, attempting to approve request: [#{miq_request.description}]")
    end

  end

  ####### end

  def deny(userid, reason)
    user = userid.kind_of?(User) ? userid : User.find_by_userid(userid)
    raise "not authorized" unless authorized?(user)
    update_attributes(:state => "denied", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)
    miq_request.approval_denied
  end

  def authorized?(userid)
    user = userid.kind_of?(User) ? userid : User.find_by_userid(userid)
    return false unless user

    return true if user.role_allows?(:identifier => "miq_request_approval")
    return true if approver.kind_of?(User) && approver == user

    false
  end
end
