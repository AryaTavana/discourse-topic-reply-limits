# frozen_string_literal: true

RSpec.describe DiscourseTopicReplyLimits::SubscriptionCycle do
  describe ".at" do
    it "renews on the purchase anniversary at the same time" do
      purchased_at = Time.zone.parse("2026-07-25 14:37:21 UTC")

      before_anniversary =
        described_class.at(
          anchor: purchased_at,
          time: Time.zone.parse("2026-08-25 14:37:20 UTC")
        )
      at_anniversary =
        described_class.at(
          anchor: purchased_at,
          time: Time.zone.parse("2026-08-25 14:37:21 UTC")
        )

      expect(before_anniversary).to include(
        index: 0,
        started_at: purchased_at,
        ends_at: Time.zone.parse("2026-08-25 14:37:21 UTC")
      )
      expect(at_anniversary).to include(
        index: 1,
        started_at: Time.zone.parse("2026-08-25 14:37:21 UTC"),
        ends_at: Time.zone.parse("2026-09-25 14:37:21 UTC")
      )
    end

    it "anchors every cycle to January 31 without drifting" do
      purchased_at = Time.zone.parse("2027-01-31 09:15:00 UTC")

      february =
        described_class.at(
          anchor: purchased_at,
          time: Time.zone.parse("2027-02-28 09:15:00 UTC")
        )
      march =
        described_class.at(
          anchor: purchased_at,
          time: Time.zone.parse("2027-03-31 09:15:00 UTC")
        )

      expect(february).to include(
        index: 1,
        started_at: Time.zone.parse("2027-02-28 09:15:00 UTC"),
        ends_at: Time.zone.parse("2027-03-31 09:15:00 UTC")
      )
      expect(march).to include(
        index: 2,
        started_at: Time.zone.parse("2027-03-31 09:15:00 UTC"),
        ends_at: Time.zone.parse("2027-04-30 09:15:00 UTC")
      )
    end
  end
end
