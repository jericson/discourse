# frozen_string_literal: true

RSpec.describe UserCommScreener do
  fab!(:target_user1) { Fabricate(:user, username: "bobscreen") }
  fab!(:target_user2) { Fabricate(:user, username: "hughscreen") }
  fab!(:target_user3) do
    user = Fabricate(:user, username: "alicescreen")
    user.user_option.update(allow_private_messages: false)
    user
  end
  fab!(:target_user4) { Fabricate(:user, username: "janescreen") }
  fab!(:target_user5) { Fabricate(:user, username: "maryscreen") }
  fab!(:other_user) { Fabricate(:user) }

  subject do
    described_class.new(
      acting_user: acting_user, target_user_ids: [
        target_user1.id,
        target_user2.id,
        target_user3.id,
        target_user4.id,
        target_user5.id
      ]
    )
  end

  it "allows initializing the class with both an acting_user_id and an acting_user" do
    acting_user = Fabricate(:user)
    screener = described_class.new(acting_user: acting_user, target_user_ids: [target_user1.id])
    expect(screener.allowing_actor_communication).to eq([target_user1.id])
    screener = described_class.new(acting_user_id: acting_user.id, target_user_ids: [target_user1.id])
    expect(screener.allowing_actor_communication).to eq([target_user1.id])
  end

  it "filters out the acting user from target_user_ids" do
    acting_user = Fabricate(:user)
    screener = described_class.new(acting_user: acting_user, target_user_ids: [target_user1.id, acting_user.id])
    expect(screener.allowing_actor_communication).to eq([target_user1.id])
  end

  context "when the actor is not staff" do
    fab!(:acting_user) { Fabricate(:user) }
    fab!(:muted_user) { Fabricate(:muted_user, user: target_user1, muted_user: acting_user) }
    fab!(:ignored_user) { Fabricate(:ignored_user, user: target_user2, ignored_user: acting_user, expiring_at: 2.days.from_now) }

    describe "#allowing_actor_communication" do
      it "returns the usernames of people not ignoring, muting, or disallowing PMs from the actor" do
        expect(subject.allowing_actor_communication).to match_array([target_user4.id, target_user5.id])
      end
    end

    describe "#preventing_actor_communication" do
      it "returns the usernames of people ignoring, muting, or disallowing PMs from the actor" do
        expect(subject.preventing_actor_communication).to match_array([target_user1.id, target_user2.id, target_user3.id])
      end
    end

    describe "#ignoring_or_muting_actor?" do
      it "does not raise an error when looking for a user who has no communication preferences" do
        expect { subject.ignoring_or_muting_actor?(target_user5.id) }.not_to raise_error
      end

      it "returns true for a user muting the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user1.id)).to eq(true)
      end

      it "returns true for a user ignoring the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user2.id)).to eq(true)
      end

      it "returns false for a user neither ignoring or muting the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user3.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.ignoring_or_muting_actor?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#disallowing_pms_from_actor?" do
      it "returns true for a user disallowing all PMs" do
        expect(subject.disallowing_pms_from_actor?(target_user3.id)).to eq(true)
      end

      it "returns true for a user allowing only PMs for certain users but not the actor" do
        target_user4.user_option.update!(enable_allowed_pm_users: true)
        expect(subject.disallowing_pms_from_actor?(target_user4.id)).to eq(true)
      end

      it "returns false for a user allowing only PMs for certain users which the actor allowed" do
        target_user4.user_option.update!(enable_allowed_pm_users: true)
        AllowedPmUser.create!(user: target_user4, allowed_pm_user: acting_user)
        expect(subject.disallowing_pms_from_actor?(target_user4.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs or muting or ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user5.id)).to eq(false)
      end

      it "returns true for a user not disallowing PMs but still ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user1.id)).to eq(true)
      end

      it "returns true for a user not disallowing PMs but still muting" do
        expect(subject.disallowing_pms_from_actor?(target_user2.id)).to eq(true)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.disallowing_pms_from_actor?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end
  end

  context "when the actor is staff" do
    fab!(:acting_user) { Fabricate(:admin) }
    fab!(:muted_user) { Fabricate(:muted_user, user: target_user1, muted_user: acting_user) }
    fab!(:ignored_user) { Fabricate(:ignored_user, user: target_user1, ignored_user: acting_user, expiring_at: 2.days.from_now) }

    describe "#allowing_actor_communication" do
      it "returns all usernames since staff can communicate with anyone" do
        expect(subject.allowing_actor_communication).to match_array([
          target_user1.id,
          target_user2.id,
          target_user3.id,
          target_user4.id,
          target_user5.id
        ])
      end
    end

    describe "#preventing_actor_communication" do
      it "does not return any usernames since no users can prevent staff communicating with them" do
        expect(subject.preventing_actor_communication).to eq([])
      end
    end

    describe "#ignoring_or_muting_actor?" do
      it "returns false for a user muting the staff" do
        expect(subject.ignoring_or_muting_actor?(target_user1.id)).to eq(false)
      end

      it "returns false for a user ignoring the staff actor" do
        expect(subject.ignoring_or_muting_actor?(target_user2.id)).to eq(false)
      end

      it "returns false for a user neither ignoring or muting the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user3.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.ignoring_or_muting_actor?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#disallowing_pms_from_actor?" do
      it "returns false for a user disallowing all PMs" do
        expect(subject.disallowing_pms_from_actor?(target_user3.id)).to eq(false)
      end

      it "returns false for a user allowing only PMs for certain users but not the actor" do
        target_user4.user_option.update!(enable_allowed_pm_users: true)
        expect(subject.disallowing_pms_from_actor?(target_user4.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs or muting or ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user5.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs but still ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user1.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs but still muting" do
        expect(subject.disallowing_pms_from_actor?(target_user2.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.disallowing_pms_from_actor?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end
  end

  describe "actor preferences" do
    fab!(:acting_user) { Fabricate(:user) }
    fab!(:muted_user) { Fabricate(:muted_user, user: acting_user, muted_user: target_user1) }
    fab!(:ignored_user) { Fabricate(:ignored_user, user: acting_user, ignored_user: target_user2, expiring_at: 2.days.from_now) }
    fab!(:allowed_pm_user1) { AllowedPmUser.create!(user: acting_user, allowed_pm_user: target_user1) }
    fab!(:allowed_pm_user2) { AllowedPmUser.create!(user: acting_user, allowed_pm_user: target_user2) }
    fab!(:allowed_pm_user3) { AllowedPmUser.create!(user: acting_user, allowed_pm_user: target_user4) }

    describe "#actor_preventing_communication" do
      it "returns the user_ids of the users the actor is ignoring, muting, or disallowing PMs from" do
        acting_user.user_option.update!(enable_allowed_pm_users: true)
        expect(subject.actor_preventing_communication).to match_array([
          target_user1.id, target_user2.id, target_user3.id, target_user5.id
        ])
      end
    end

    describe "#actor_allowing_communication" do
      it "returns the user_ids of the users who the actor is not ignoring, muting, or disallowing PMs from" do
        acting_user.user_option.update!(enable_allowed_pm_users: true)
        expect(subject.actor_allowing_communication).to match_array([target_user4.id])
      end
    end

    describe "#actor_ignoring?" do
      it "returns true for user ids that the actor is ignoring" do
        expect(subject.actor_ignoring?(target_user2.id)).to eq(true)
        expect(subject.actor_ignoring?(target_user4.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.actor_ignoring?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#actor_muting?" do
      it "returns true for user ids that the actor is muting" do
        expect(subject.actor_muting?(target_user1.id)).to eq(true)
        expect(subject.actor_muting?(target_user2.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.actor_muting?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#actor_disallowing_pms?" do
      it "returns true for user ids that the actor is not explicitly allowing PMs from" do
        acting_user.user_option.update!(enable_allowed_pm_users: true)
        expect(subject.actor_disallowing_pms?(target_user3.id)).to eq(true)
        expect(subject.actor_disallowing_pms?(target_user1.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { subject.actor_disallowing_pms?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#actor_disallowing_all_pms?" do
      it "returns true if the acting user has disabled private messages altogether" do
        expect(subject.actor_disallowing_all_pms?).to eq(false)
        acting_user.user_option.update!(allow_private_messages: false)
        expect(subject.actor_disallowing_all_pms?).to eq(true)
      end
    end
  end
end
