#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class RelayableRetraction < SignedRetraction
  xml_name :relayable_retraction
  xml_attr :parent_author_signature

  attr_accessor :parent_author_signature

  def signable_accessors
    super - ['parent_author_signature']
  end

  # @param sender [User]
  # @param target [Object]
  def self.build(sender, target)
    retraction = super
    retraction.parent_author_signature = retraction.sign_with_key(sender.encryption_key) if defined?(target.parent) && sender.person == target.parent.author
    retraction
  end

  def parent
    return nil unless self.target.present?
    self.target.parent
  end

  def diaspora_handle
    self.sender_handle
  end

  def relayable?
    true
  end

  def receive(recipient, sender)
    if self.target.nil?
      Rails.logger.info("event=retraction status=abort reason='no post found' sender=#{sender.diaspora_handle} target_guid=#{target_guid}")
      return
    elsif self.parent.author == recipient.person && self.target_author_signature_valid?
      #this is a retraction from the downstream object creator, and the recipient is the upstream owner
      self.parent_author_signature = self.sign_with_key(recipient.encryption_key)
      Postzord::Dispatcher.build(recipient, self).post
      self.perform(recipient)
    elsif self.parent_author_signature_valid?
      #this is a retraction from the upstream owner
      self.perform(recipient)
    else
      Rails.logger.info("event=receive status=abort reason='object signature not valid' recipient=#{recipient.diaspora_handle} sender=#{self.parent.author.diaspora_handle} payload_type=#{self.class} parent_id=#{self.parent.id}")
      return
    end
    self
  end

  def parent_author_signature_valid?
    verify_signature(self.parent_author_signature, self.parent.author)
  end
end
