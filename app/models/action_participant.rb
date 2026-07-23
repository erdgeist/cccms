class ActionParticipant < ApplicationRecord
  belongs_to :node_action
  belongs_to :subject, :polymorphic => true
end
