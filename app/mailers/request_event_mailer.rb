# Emails about a request's status changes (GS-11), sent by RequestEventNotificationJob. Each one
# says what happened in the thread's own terms, quotes the note if there is one, and links to the
# request page.
#
# Every email about one request has the same subject, so mail apps group them into one
# conversation. The first line of the email says what changed.
class RequestEventMailer < ApplicationMailer
  # Close-out events carry a fixed text, then the person's own note as a second paragraph.
  FIXED_TEXT_KINDS = %w[closed_out item_removed moved].freeze

  # A status change on `recipient`'s side of the request (see ItemRequestService.event_kind).
  def event_update(event, recipient)
    @request = event.item_request
    @item = @request.item
    @recipient = recipient
    kind = ItemRequestService.event_kind(event, @request)
    @lead = event_lead(kind, event, event.user.display_name, @item.title)
    @note = note_for(kind, event)
    @note_author = event.user.display_name
    deliver_update
  end

  # Something another request on the item did to `request`: another requester was chosen
  # (KIND_OTHER_CHOSEN), or the accepted request fell through (KIND_AVAILABLE_AGAIN).
  def item_notice(kind, request, _event)
    @request = request
    @item = request.item
    @recipient = request.requester
    title = @item.title
    @lead =
      case kind
      when UserNotification::KIND_OTHER_CHOSEN
        "The owner accepted another request for #{title}. Your request stays open: if that falls through, they can still choose you."
      when UserNotification::KIND_AVAILABLE_AGAIN
        "The request the owner had accepted for #{title} fell through, so it's available again. Your request is still open."
      else
        raise ArgumentError, "Unknown notice kind: #{kind}"
      end
    deliver_update
  end

  private

  def deliver_update
    group = CommunityGroupService.preferred_group_for_item_and_user(@item, @recipient)
    @action_url = CommunityGroupService.public_url_for(path: "/item_request_details?id=#{@request.id}", group: group)
    mail(to: @recipient.email_address, subject: subject_for(@request, @recipient), template_name: "request_update")
  end

  # "Update on your request for Book: Dune" to the requester, and
  # "Update on Sam Lee's request for Book: Dune" to the owner.
  def subject_for(request, recipient)
    whose = recipient.id == request.requester_id ? "your" : "#{request.requester.display_name}'s"
    "Update on #{whose} request for #{request.item.type}: #{request.item.title}"
  end

  # The first line of the email for each kind of event (the table in GS-11).
  def event_lead(kind, event, author, title)
    case kind
    when "accepted"
      "#{author} accepted your request for #{title}. Arrange the pickup with them in Messages."
    when "declined"
      "#{author} declined your request for #{title}."
    when "closed_out"
      "#{title} was given to another requester, so your request is closed."
    when "item_removed"
      "#{author} removed #{title}, so your request is closed."
    when "moved"
      if event.content.to_s.start_with?(ItemRequestService::ITEM_REMOVED_MOVED_NOTE)
        "The donor removed their copy of #{title}. You've been moved to a new wish for the same item, and we'll email you when someone else offers it."
      else
        "This copy of #{title} went to another requester. You've been moved to a new wish for the same item, and we'll email you when someone else offers it."
      end
    when "completed"
      "#{author} marked the handoff of #{title} as complete. Enjoy!"
    when "cancelled"
      "#{author} cancelled their request for #{title}."
    when "reopened"
      "#{author} reopened their request for #{title}. It's waiting for your answer again."
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
