#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe LikesController do
  before do
    @alices_aspect = alice.aspects.where(:name => "generic").first
    @bobs_aspect = bob.aspects.where(:name => "generic").first

    sign_in :user, alice
  end

  [Comment, Post].each do |class_const|
    context class_const.to_s do
        let(:id_field){
          "#{class_const.to_s.underscore}_id"
        }

      describe '#create' do
        let(:like_hash) {
          {:positive => 1,
           id_field => "#{@target.id}"}
        }
        let(:dislike_hash) {
          {:positive => 0,
           id_field => "#{@target.id}"}
        }

        context "on my own post" do
          before do
            @target = alice.post :status_message, :text => "AWESOME", :to => @alices_aspect.id

            @target = alice.comment "hey", :post => @target if class_const == Comment
          end

          it 'responds to format js' do
            post :create, like_hash.merge(:format => 'js')
            response.code.should == '201'
          end
        end

        context "on a post from a contact" do
          before do
            @target = bob.post :status_message, :text => "AWESOME", :to => @bobs_aspect.id
            @target = bob.comment "hey", :post => @target if class_const == Comment
          end

          it 'likes' do
            post :create, like_hash
            response.code.should == '201'
          end

          it 'dislikes' do
            post :create, dislike_hash
            response.code.should == '201'
          end

          it "doesn't post multiple times" do
            alice.like(1, :target => @target)
            post :create, dislike_hash
            response.code.should == '422'
          end
        end

        context "on a post from a stranger" do
          before do
            @target = eve.post :status_message, :text => "AWESOME", :to => eve.aspects.first.id
            @target = eve.comment "hey", :post => @target if class_const == Comment
          end

          it "doesn't post" do
            alice.should_not_receive(:like)
            post :create, like_hash
            response.code.should == '422'
          end
        end
      end

      describe '#index' do
        before do
          @message = alice.post(:status_message, :text => "hey", :to => @alices_aspect.id)
          @message = alice.comment( "hey", :post => @message) if class_const == Comment
        end

        it 'generates a jasmine fixture', :fixture => true do
          get :index, id_field => @message.id

          save_fixture(response.body, "ajax_likes_on_#{class_const.to_s.underscore}")
        end

        it 'returns a 404 for a post not visible to the user' do
          sign_in eve
          get :index, id_field => @message.id
        end

        it 'returns an array of likes for a post' do
          like = bob.build_like(:positive => true, :target => @message)
          like.save!

          get :index, id_field => @message.id
          assigns[:likes].map(&:id).should == @message.likes.map(&:id)
        end

        it 'returns an empty array for a post with no likes' do
          get :index, id_field => @message.id
          assigns[:likes].should == []
        end
      end

      describe '#destroy' do
        before do
          @message = bob.post(:status_message, :text => "hey", :to => @alices_aspect.id)
          @message = bob.comment( "hey", :post => @message) if class_const == Comment
          @like = alice.build_like(:positive => true, :target => @message)
          @like.save
        end

        it 'lets a user destroy their like' do
          expect {
            delete :destroy, :format => "js", id_field => @like.target_id, :id => @like.id
          }.should change(Like, :count).by(-1)
          response.status.should == 200
        end

        it 'does not let a user destroy other likes' do
          like2 = eve.build_like(:positive => true, :target => @message)
          like2.save

          expect {
            delete :destroy, :format => "js", id_field => like2.target_id, :id => like2.id
          }.should_not change(Like, :count)

          response.status.should == 403
        end
      end
    end
  end
end
