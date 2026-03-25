# frozen_string_literal: true

require "spec_helper"

RSpec.describe SentEmails do
  it "has a version number" do
    expect(SentEmails::VERSION).not_to be nil
  end

  describe "Configuration#content_filter" do
    it "raises ArgumentError when called without a block" do
      config = SentEmails::Configuration.new
      expect { config.content_filter }.to raise_error(ArgumentError, "content_filter requires a block")
    end
  end
end
