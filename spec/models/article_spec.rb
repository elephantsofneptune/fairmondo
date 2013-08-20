#
#
# == License:
# Fairnopoly - Fairnopoly is an open-source online marketplace.
# Copyright (C) 2013 Fairnopoly eG
#
# This file is part of Fairnopoly.
#
# Fairnopoly is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Fairnopoly is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Fairnopoly.  If not, see <http://www.gnu.org/licenses/>.
#
require 'spec_helper'

describe Article do

  let(:article) { FactoryGirl.create(:article) }
  subject { article }

  describe "::Base" do
    describe "associations" do
      it {should have_many :images}
      it {should have_and_belong_to_many :categories}
      it {should belong_to :seller}
      it {should have_many :buyer}
      it {should belong_to(:transaction).dependent(:destroy)}
    end

    describe "amoeba" do
      it "should copy an article with images" do
        article = FactoryGirl.create :article, :with_fixture_image
        testpath = article.images.first.image.path # The image needs to be in place !!!
        FileUtils.mkpath File.dirname(testpath) # make the dir
        FileUtils.cp(Rails.root.join('spec', 'fixtures', 'test.png'), testpath) #copy the image

        dup = article.amoeba_dup
        dup.images[0].id.should_not eq article.images[0].id
        dup.images[0].image_file_name.should eq article.images[0].image_file_name
      end
    end

    describe "methods" do
      describe "#owned_by?(user)" do
        it "should return false when user is nil" do
          article.owned_by?(nil).should be_false
        end

        it "should return false when article doesn't belong to user" do
          article.owned_by?(FactoryGirl.create(:user)).should be_false
        end

        it "should return true when article belongs to user" do
          article.owned_by?(article.seller).should be_true
        end
      end
    end
  end


  describe "::BuildTransaction" do
    it "should build a specific transaction" do
       article.build_specific_transaction.should be_a PreviewTransaction
    end
  end

  describe "::FeesAndDonations" do

    #at the moment we do not have friendly percentece any more
    #describe "friendly_percent_calculated" do
      #it "should call friendly_percent_result" do
        #article.should_receive :friendly_percent_result
        #article.friendly_percent_calculated
      #end
    #end

    describe "#fee_percentage" do
      it "should return the fair percentage when article.fair" do
        article.fair = true
        article.send('fee_percentage').should == 0.03
      end

      it "should return the default percentage when !article.fair" do
        article.send('fee_percentage').should == 0.06
      end
    end

    describe "#calculate_fees_and_donations" do
      #expand these unit tests!
      it "should return zeros on fee and fair cents with a friendly_percent of gt 100" do
        article.friendly_percent = 101
        article.calculate_fees_and_donations
        article.calculated_fair.should eq 0
        article.calculated_fee.should eq 0
      end

      it "should return zeros on fee and fair cents with a price of 0" do
        article.price = 0
        article.calculate_fees_and_donations
        article.calculated_fair.should eq 0
        article.calculated_fee.should eq 0
      end

      it "should return the max fee when calculated_fee gt max fee" do
        article.price = 9999
        article.fair = false
        article.calculate_fees_and_donations
        article.calculated_fee.should eq Money.new(3000)
      end

      it "should always round the fair cents up" do
        article.price = 789.23
        article.fair = false
        article.calculate_fees_and_donations
        article.calculated_fair.should eq Money.new(790)
      end

    end
  end

  describe "::Attributes" do
    describe "Validations" do
      it "should throw an error if selected default_transport option is not true for transport_'option'" do
        article.default_transport = "pickup"
        article.transport_pickup = false
        article.save
        article.errors[:default_transport].should == [I18n.t("errors.messages.invalid_default_transport")]
      end

      it "should throw an error if no payment option is selected" do
        article.payment_cash = false
        article.save
        article.errors[:payment_details].should == [I18n.t("article.form.errors.invalid_payment_option")]
      end

      it "should throw an error if bank transfer is selected, but bank data is missing" do
        article.seller.stub(:bank_account_exists?).and_return(false)
        article.payment_bank_transfer = true
        article.save
        article.errors[:payment_bank_transfer].should == [I18n.t("article.form.errors.bank_details_missing")]
      end

        it "should throw an error if paypal is selected, but bank data is missing" do
        article.payment_paypal = true
        article.save
        article.errors[:payment_paypal].should == [I18n.t("article.form.errors.paypal_details_missing")]
      end
    end

    describe "methods" do

      describe "#transport_price" do
        let (:article) { FactoryGirl.create :article, :with_all_transports }

        it "should return an article's default_transport's price" do
          article.transport_price.should eq Money.new 0
        end

        it "should return an article's type1 transport price" do
          article.transport_price("type1").should eq Money.new 2000
        end

        it "should return an article's type2 transport price" do
          article.transport_price("type2").should eq Money.new 1000
        end

        it "should return an article's pickup transport price" do
          article.transport_price("pickup").should eq Money.new 0
        end
      end

      describe "#transport_provider" do
        let (:article) { FactoryGirl.create :article, :with_all_transports }

        it "should return an article's default_transport's provider" do
          article.transport_provider.should eq nil
        end

        it "should return an article's type1 transport provider" do
          article.transport_provider("type1").should eq 'DHL'
        end

        it "should return an article's type2 transport provider" do
          article.transport_provider("type2").should eq 'Hermes'
        end

        it "should return an article's pickup transport provider" do
          article.transport_provider("pickup").should eq nil
        end
      end

      describe "#total_price" do
        let (:article) { FactoryGirl.create :article, :with_all_transports }

        it "should return the correct price for cash_on_delivery payments" do
          expected = article.price + article.transport_type1_price + article.payment_cash_on_delivery_price
          article.total_price("type1", "cash_on_delivery").should eq expected
        end

        it "should return the correct price for non-cash_on_delivery payments" do
          expected = article.price + article.transport_type2_price
          article.total_price("type2", "cash").should eq expected
        end
      end

      describe "#price_without_vat" do
        it "should return the correct price" do
          article = FactoryGirl.create :article, price: 100, vat: 19
          article.price_without_vat.should eq Money.new 8100
        end
      end

      describe "#vat_price" do
        it "should return the correct price" do
          article = FactoryGirl.create :article, price: 100, vat: 19
          article.vat_price.should eq Money.new 1900
        end
      end

      describe "#selectable_transports" do
        it "should call the private selectable function" do
          article.should_receive(:selectable).with("transport")
          article.selectable_transports
        end
      end

      describe "#selectable_payments" do
        it "should call the private selectable function" do
          article.should_receive(:selectable).with("payment")
          article.selectable_payments
        end
      end

      describe "#selectable (private)" do
        it "should return an array with selected transport options, the default being first" do
          output = FactoryGirl.create(:article, :with_all_transports).send(:selectable, "transport")
          output[0].should eq :pickup
          output.should include :type1
          output.should include :type2
        end
      end
    end
  end

  describe "::Images" do
    describe "methods" do
      describe "#title_image_url" do
        it "should return the first image's URL when one exists" do
          article.title_image_url.should match %r#/system/images/000/000/001/original/image#
        end

        it "should return the missing-image-url when no image is set" do
          article = FactoryGirl.create :article, :without_image
          article.title_image_url.should eq 'missing.png'
        end

         it "should return the first image's URL when one exists" do
          article.images = [FactoryGirl.build(:fixture_image),FactoryGirl.build(:fixture_image)]
          article.images.each do |image|
            image.is_title = true
            image.save
          end
          article.save
          article.errors[:images].should == [I18n.t("article.form.errors.only_one_title_image")]
        end

      end
    end
  end

  describe "::Categories" do
    describe "#size_validator" do
      it "should validate size of categories" do
        article_0cat = FactoryGirl.build :article
        article_0cat.categories = []
        article_1cat = FactoryGirl.build :article
        article_2cat = FactoryGirl.build :article, :with_child_category
        article_3cat = FactoryGirl.build :article, :with_3_categories

        article_0cat.should_not be_valid
        article_1cat.should be_valid
        article_2cat.should be_valid
        article_3cat.should_not be_valid
      end
    end


  end

  describe "::Template" do
    before do
      @article = FactoryGirl.build :article, article_template_id: 1, article_template: ArticleTemplate.new(),save_as_template: "1"
      @article.article_template.user = nil
    end

    describe "#save_as_template?" do
      it "should return true when the save_as_template attribute is 1" do
        @article.save_as_template?.should be_true
      end

      it "should return false when the save_as_template attribute is 0" do
        @article.save_as_template = "0"
        @article.save_as_template?.should be_false
      end

    end

    describe "#not_save_as_template?" do
      it "should return true when the save_as_template attribute is 1" do
        @article.not_save_as_template?.should be_false
      end

      it "should return false when the save_as_template attribute is 0" do
        @article.save_as_template = "0"
        @article.not_save_as_template?.should be_true
      end

    end

    describe "#set_user_on_template" do
      it "should set the article's seller as the template's owner" do
        @article.article_template.user.should be_nil

        @article.set_user_on_template
        @article.article_template.user.should eq @article.seller
      end
    end

    describe "#build_and_save_template" do
      it "should request an amoeba duplication" do
        @article.should_receive(:amoeba_dup).and_return FactoryGirl.build :article
        @article.build_and_save_template
      end

      it "should unset its own article_template_id" do
        @article.stub(:amoeba_dup).and_return FactoryGirl.build :article
        @article.build_and_save_template
        @article.article_template_id.should be_nil
      end

      it "should save a new article as a template" do
        @article.stub(:amoeba_dup).and_return FactoryGirl.build :article
        Article.any_instance.should_receive :save
        @article.build_and_save_template
      end
    end
  end
end
