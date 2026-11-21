# Emails about a request's status changes (GS-11), sent by RequestEventNotificationJob. Each one
# says what happened in the thread's own terms, quotes the note if there is one, and links to the
# request page.
class RequestEventMailer < ApplicationMailer
  # Close-out events carry a fixed text, then the person's own note as a second paragraph.
  FIXED_TEXT_KINDS = %w[closed_out item_removed moved].freeze

  # A status change on `recipient`'s side of the request (see ItemRequestService.event_kind).
  def event_update(event, recipient)
    @request = event.item_request
    @item = @request.item
    @recipient = recipient
    kind = ItemRequestService.event_kind(event, @request)
    subject, @lead = event_copy(kind, event, event.user.display_name, @item.title)
    @note = note_for(kind, event)
    @note_author = event.user.display_name
    deliver_to(subject)
  end

  # Something another request on the item did to `request`: another requester was chosen
  # (KIND_OTHER_CHOSEN), or the accepted request fell through (KIND_AVAILABLE_AGAIN).
  def item_notice(kind, request, _event)
    @request = request
    @item = request.item
    @recipient = request.requester
    title = @item.title
    subject, @lead =
      case kind
      when UserNotification::KIND_OTHER_CHOSEN
        [ "Someone else was chosen for #{title}",
          "The owner accepted another request for #{title}. Your request stays open: if that falls through, they can still choose you." ]
      when UserNotification::KIND_AVAILABLE_AGAIN
        [ "#{title} is available again",
          "The request the owner had accepted for #{title} fell through, so it's available again. Your request is still open." ]
      else
        raise ArgumentError, "Unknown notice kind: #{kind}"
      end
    deliver_to(subject)
  end

  private

  def deliver_to(subject)
    group = CommunityGroupService.preferred_group_for_item_and_user(@item, @recipient)
    @action_url = CommunityGroupService.public_url_for(path: "/item_request_details?id=#{@request.id}", group: group)
    mail(to: @recipient.email_address, subject: subject, template_name: "request_update")
  end

  # [subject, first line of the email] for each kind of event (the table in GS-11).
  def event_copy(kind, event, author, title)
    case kind
    when "accepted"
      [ "Good news: #{title} is yours", "#{author} accepted your request for #{title}. Arrange the pickup with them in Messages." ]
    when "declined"
      [ "Update on your request for #{title}", "#{author} declined your request for #{title}." ]
    when "closed_out"
      [ "#{title} went to another requester", "#{title} was given to another requester, so your request is closed." ]
    when "item_removed"
      [ "#{title} was removed by its owner", "#{author} removed #{title}, so your request is closed." ]
    when "moved"
      if event.content.to_s.start_with?(ItemRequestService::ITEM_REMOVED_MOVED_NOTE)
        [ "The donor removed their copy of #{title}, and your wish is still listed",
          "The donor removed their copy of #{title}. You've been moved to a new wish for the same item, and we'll email you when someone else offers it." ]
      else
        [ "#{title} went to another requester, and your wish is still listed",
          "This copy of #{title} went to another requester. You've been moved to a new wish for the same item, and we'll email you when someone else offers it." ]
      end
    when "completed"
      [ "Enjoy #{title}!", "#{author} marked the handoff of #{title} as complete. Enjoy!" ]
    when "cancelled"
      [ "#{author} cancelled their request for #{title}", "#{author} cancelled their request for #{title}." ]
    when "reopened"
      [ "#{author} reopened their request for #{title}", "#{author} reopened their request for #{title}. It's waiting for your answer again." ]
    else
      raise ArgumentError, "No email for event kind #{kind.inspect}"
    end
  end

  # What the person typed with the change, if anything.
  def note_for(kind, event)
    content = event.content.to_s
    note = FIXED_TEXT_KINDS.include?(kind) ? content.split("\n\n", 2)[1] : content
    note.to_s.strip.presence
  end
end
