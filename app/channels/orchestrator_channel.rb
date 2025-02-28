# frozen_string_literal: true

class OrchestratorChannel < ApplicationCable::Channel
  def subscribed
    stream_for Retrospective.find(params[:retrospective_id])
    return unless current_participant

    current_participant.reload

    Rails.logger.debug "#{current_participant.surname} (#{current_participant.id}) subscribed"
    current_participant.update!(logged_in: true)
    broadcast_to(
      current_participant.retrospective,
      action: 'refreshParticipant',
      parameters: { participant: current_participant.profile }
    )

    current_participant.retrospective.reset_original_facilitator! if current_participant.original_facilitator?
  end

  def unsubscribed
    return unless current_participant

    Rails.logger.debug "#{current_participant.surname} (#{current_participant.id}) unsubscribed"
    current_participant.update!(logged_in: false)

    InactivityJob.set(wait_until: Participant::INACTIVITY_DELAY.seconds.from_now).perform_later(current_participant)
  end

  def start_timer(data)
    return unless current_participant.reload.facilitator?

    timer_end_at = Time.zone.now + data['duration'].to_i.seconds
    broadcast_to(
      current_participant.retrospective,
      action: 'setTimer',
      parameters: { timer_end_at: timer_end_at }
    )
    current_participant.retrospective.update!(timer_end_at: timer_end_at)
  end

  def elect_revealer(data)
    return unless current_participant.reload.facilitator?

    retrospective = current_participant.retrospective
    current_revealer = retrospective.revealer
    new_revealer = retrospective.participants.find(data['uuid'])
    retrospective.update!(revealer: new_revealer)
    if current_revealer
      current_revealer.reload
      broadcast_to(retrospective, action: 'refreshParticipant', parameters: { participant: current_revealer.profile })
    end
    broadcast_to(retrospective, action: 'refreshParticipant', parameters: { participant: new_revealer.reload.profile })
  end

  def reveal_reflection(data)
    return unless current_participant.reload.revealer?

    retrospective = current_participant.retrospective
    reflection = retrospective.reflections.find(data['uuid'])
    reflection.update!(revealed: true)
    broadcast_to(retrospective, action: 'revealReflection', parameters: { reflection: reflection.readable })
  end

  def drop_revealer_token
    return unless current_participant.reload.revealer?

    retrospective = current_participant.retrospective
    retrospective.update!(revealer: nil)
    current_participant.reload
    broadcast_to(retrospective, action: 'refreshParticipant', parameters: { participant: current_participant.profile })
  end

  def change_discussed_reflection(data)
    return unless current_participant.reload.facilitator?

    retrospective = current_participant.retrospective
    reflection = retrospective.reflections.includes(:topic, :owner, zone: :retrospective).find(data['uuid'])
    retrospective.update!(discussed_reflection: reflection)
    broadcast_to(retrospective, action: 'setDiscussedReflection', parameters: { reflection: reflection.readable })
  end

  def change_step
    return unless current_participant.reload.facilitator?

    bare_retrospective = Retrospective.select(:step).find(current_participant.retrospective_id)
    retrospective =
      Retrospective
        .includes(*bare_retrospective.relationships_to_load(bare_retrospective.next_step))
        .find(current_participant.retrospective_id)

    retrospective.next_step!
  end
end
