require "./spec_helper"

describe Charqui do
  it "Should parse ratio correctly" do
    cli = Charqui::CLI.new
    cli.parse_ratio "1:1"
    cli.ratio.should eq(0.5)

    cli.parse_ratio "80:20"
    cli.ratio.should eq(0.8)
  end
end
