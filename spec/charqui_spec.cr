require "./spec_helper"

describe Charqui do
  it "Should parse ratio correctly" do
    cli = Charqui::CLI.new
    cli.parse_ratio "1:1"
    cli.ratio.should be_close(0.5, 1e-3)

    cli.parse_ratio "80:20"
    cli.ratio.should be_close(0.8, 1e-3)
  end

  it "Should parse sizes correctly" do
    Charqui::SizeKB.new("10mb").value.should eq(10 * 1024)
    Charqui::SizeKB.new("10Mb").value.should eq(10 * 1024)
    Charqui::SizeKB.new("10MB").value.should eq(10 * 1024)
    Charqui::SizeKB.new("1.5MB").value.should eq((1.5 * 1024).to_i)
    Charqui::SizeKB.new("10KB").value.should eq(10)
    Charqui::SizeKB.new("10kB").value.should eq(10)
    Charqui::SizeKB.new("1GB").value.should eq(1 * 1024 * 1024)

    # Parse decimal values.
    Charqui::SizeKB.new("1.5MB").value.should eq((1.5 * 1024).to_i)

    expect_raises Charqui::AppError do
      # The string has to only have the string specifier.
      Charqui::SizeKB.new("1.5MBz")
    end

    expect_raises Charqui::AppError do
      Charqui::SizeKB.new("1..2MB")
    end

    expect_raises Charqui::AppError do
      # The string *has* to contain the size specifier as the target size
      # cannot be simply bytes, *for now*
      Charqui::SizeKB.new("1234")
    end
  end
end
