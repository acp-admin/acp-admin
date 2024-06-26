# frozen_string_literal: true

require "rails_helper"

describe SpamDetector do
  def spam?(member)
    SpamDetector.spam?(member)
  end

  it "detects too long note" do
    member = Member.new(note: "fobar" * 1000 + "A")
    expect(spam?(member)).to eq true
  end

  it "detects too long food note" do
    member = Member.new(food_note: "fobar" * 1000 + "A")
    expect(spam?(member)).to eq true
  end

  it "detects duplicated long texts" do
    member = Member.new(
      note:
        "Bonjour,\r\n" \
        "\r\n" \
        "Avez-vous un problème d'E-Réputation ? Avis/liens négatifs.\r\n" \
        "\r\n" \
        "Un expert me contacte : http://foo.bar\r\n" \
        "\r\n" \
        "Cordialement,\r\n" \
        "\r\n" \
        "L'équipe E-Réputation",
      come_from:
        "Bonjour," \
        "Avez-vous un problème d'E-Réputation ? Avis/liens négatifs." \
        "Un expert me contacte : http://foo.bar" \
        "Cordialement," \
        "L'équipe E-Réputation")
    expect(spam?(member)).to eq true

    expect(member.note).to include " "
    expect(member.come_from).to include " "
  end

  it "skips duplicated short texts" do
    member = Member.new(
      note: "Merci  ",
      come_from: "Merci")
    expect(spam?(member)).to eq false
  end

  it "detects wrong zip" do
    member = Member.new(zip: "153535")
    expect(spam?(member)).to eq true
  end

  it "detects cyrillic address" do
    member = Member.new(address: "РњРѕСЃРєРІР°")
    expect(spam?(member)).to eq true
  end

  it "detects cyrillic city" do
    member = Member.new(city: "РњРѕСЃРєРІР°")
    expect(spam?(member)).to eq true
  end

  it "detects cyrillic come_from" do
    member = Member.new(come_from: "Р РѕСЃСЃРёСЏ")
    expect(spam?(member)).to eq true
  end

  it "detects non native language text" do
    member = Member.new(note: "¿Está buscando una interfaz de contabilidad en la nube que haga que el funcionamiento de su empresa sea fácil, rápido y seguro?")
    expect(spam?(member)).to eq true
  end

  it "ignores blank text" do
    member = Member.new(food_note: "")
    expect(spam?(member)).to eq false
  end

  it "ignores short text" do
    member = Member.new(food_note: "YEAH ROCK ON!")
    expect(spam?(member)).to eq false
  end

  it "accepts native language text" do
    member = Member.new(note: "Je me réjouis vraiment de recevoir mon panier!" * 3)
    expect(spam?(member)).to eq false
  end

  specify "allowed country" do
    ENV["ALLOWED_COUNTRY_CODES"] = "CH,FR"
    member = Member.new(country_code: "CH")
    expect(spam?(member)).to eq false
  ensure
    ENV["ALLOWED_COUNTRY_CODES"] = nil
  end

  specify "allowed countries not enabled" do
    ENV["ALLOWED_COUNTRY_CODES"] = nil
    member = Member.new(country_code: "VG")
    expect(spam?(member)).to eq false
  end

  specify "non allowed country" do
    ENV["ALLOWED_COUNTRY_CODES"] = "CH,FR"
    member = Member.new(country_code: "VG")
    expect(spam?(member)).to eq true
  ensure
    ENV["ALLOWED_COUNTRY_CODES"] = nil
  end
end
