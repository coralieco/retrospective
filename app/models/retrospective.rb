class Retrospective < ApplicationRecord
  has_many :participants
  has_one :organizer, -> { order(:created_at).limit(1) }, class_name: 'Participant'

  enum kind: {
    kds: 'kds',
    kalm: 'kalm',
    daki: 'daki',
    starfish: 'starfish',
    pmi: 'pmi',
    glad_sad_mad: 'glad_sad_mad',
    four_l: 'four_l',
    sailboat: 'sailboat',
    truths_lie: 'truths_lie',
    twitter: 'twitter',
    timeline: 'timeline',
    traffic_lights: 'traffic_lights',
    oscars_gerards: 'oscars_gerards',
    star_wars: 'star_wars',
    day_z: 'day_z',
    dixit: 'dixit',
    postcard: 'postcard'
  }

  def as_json
    {
      id: id,
      name: name,
      kind: kind,
      initialParticipants: participants.map(&:profile)
    }
  end

  def broadcast_order(action)
    OrchestratorChannel.broadcast_to(self, action: action)
  end
end
