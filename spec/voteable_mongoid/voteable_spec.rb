require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongoid::Voteable do
  before :all do
    @post1 = Post.create!
    @post2 = Post.create!
    
    @comment = @post2.comments.create!
    
    @user1 = User.create!
    @user2 = User.create!
  end
  
  context "just created" do
    it 'votes_count, up_votes_count, down_votes_count, votes_point should be zero' do
      @post1.up_votes_count.should == 0
      @post1.down_votes_count.should == 0
      @post1.votes_count.should == 0
      @post1.votes_point.should == 0

      @post2.up_votes_count.should == 0
      @post2.down_votes_count.should == 0
      @post2.votes_count.should == 0
      @post2.votes_point.should == 0

      @comment.up_votes_count.should == 0
      @comment.down_votes_count.should == 0
      @comment.votes_count.should == 0
      @comment.votes_point.should == 0
    end
    
    it 'up_voter_ids, down_voter_ids should be empty' do
      @post1.up_voter_ids.should be_empty
      @post1.down_voter_ids.should be_empty

      @post2.up_voter_ids.should be_empty
      @post2.down_voter_ids.should be_empty

      @comment.up_voter_ids.should be_empty
      @comment.down_voter_ids.should be_empty
    end
    
    it 'voted by voter should be empty' do
      Post.voted_by(@user1).should be_empty
      Post.voted_by(@user2).should be_empty
      
      Comment.voted_by(@user1).should be_empty
      Comment.voted_by(@user2).should be_empty
    end
        
    it 'revote post1 has no effect' do
      @post1.vote(:revote => true, :voter => @user1, :value => 'up')

      @post1.up_votes_count.should == 0
      @post1.down_votes_count.should == 0
      @post1.votes_count.should == 0
      @post1.votes_point.should == 0
    end
    
    it 'revote post2 has no effect' do
      Post.vote(:revote => true, :votee_id => @post2.id, :voter_id => @user2.id, :value => :down)
      @post2.reload
      
      @post2.up_votes_count.should == 0
      @post2.down_votes_count.should == 0
      @post2.votes_count.should == 0
      @post2.votes_point.should == 0
    end
  end
  
  context 'user1 vote up post1 the first time' do
    before :all do    
      @return = @post1.vote(:voter_id => @user1.id, :value => :up, :return_votes => true)
    end
    
    it 'validates return post' do
      @return.votes.should == {
        'up' => [@user1.id],
        'down' => [],
        'up_count' => 1,
        'down_count' => 0,
        'count' => 1,
        'point' => 1
      }

      @return.should_not be_new_record
      @return.should be_is_a(Post)
    end
    
    it 'validates' do
      @post1.up_votes_count.should == 1
      @post1.down_votes_count.should == 0
      @post1.votes_count.should == 1
      @post1.votes_point.should == 1

      @post1.vote_value(@user1).should == :up
      @post1.should be_voted_by(@user1)
      @post1.vote_value(@user2.id).should be_nil
      @post1.should_not be_voted_by(@user2.id)

      Post.voted_by(@user1).to_a.should == [ @post1 ]
      Post.voted_by(@user2).to_a.should be_empty
    end
    
    it 'user1 vote post1 has no effect' do
      Post.vote(:revote => false, :votee_id => @post1.id, :voter_id => @user1.id, :value => :up)
      @post1.reload
      
      @post1.up_votes_count.should == 1
      @post1.down_votes_count.should == 0
      @post1.votes_count.should == 1
      @post1.votes_point.should == 1
      
      @post1.vote_value(@user1.id).should == :up
    end
  end
  
  context 'user2 vote down post1 the first time' do
    before :all do
      Post.vote(:votee_id => @post1.id, :voter_id => @user2.id, :value => :down)
      @post1.reload
    end
    
    it 'post1 up_votes_count is the same' do
      @post1.up_votes_count.should == 1
    end
    
    it 'post1 vote_value on user1 is the same' do
      @post1.vote_value(@user1.id).should == :up
    end
    
    it 'down_votes_count, votes_count, and votes_point changed' do
      @post1.down_votes_count.should == 1
      @post1.votes_count.should == 2
      @post1.votes_point.should == 0
      @post1.vote_value(@user2.id).should == :down
    end
    
    it 'posts voted_by user1, user2 is post1 only' do
      Post.voted_by(@user1).to_a.should == [ @post1 ]
      Post.voted_by(@user2).to_a.should == [ @post1 ]
    end
  end
  
  context 'user1 change vote on post1 from up to down' do
    before :all do
      Post.vote(:revote => true, :votee_id => @post1.id, :voter_id => @user1.id, :value => :down)
      Mongoid::Voteable::Tasks.remake_stats
      @post1.reload
    end
    
    it 'validates' do
      @post1.up_votes_count.should == 0
      @post1.down_votes_count.should == 2
      @post1.votes_count.should == 2
      @post1.votes_point.should == -2

      @post1.vote_value(@user1.id).should == :down
      @post1.vote_value(@user2.id).should == :down

      Post.voted_by(@user1).to_a.should == [ @post1 ]
      Post.voted_by(@user2).to_a.should == [ @post1 ]
    end
  end
  
  context 'user1 vote down post2 the first time' do
    before :all do
      @post2.vote(:voter_id => @user1.id, :value => :down)
    end
    
    it 'validates' do
      @post2.up_votes_count.should == 0
      @post2.down_votes_count.should == 1
      @post2.votes_count.should == 1
      @post2.votes_point.should == -1
      
      @post2.vote_value(@user1.id).should == :down
      @post2.vote_value(@user2.id).should be_nil

      Post.voted_by(@user1).to_a.should == [ @post1, @post2 ]
    end
  end
  
  context 'user1 change vote on post2 from down to up' do
    before :all do
      Post.vote(:revote => true, :votee_id => @post2.id.to_s, :voter_id => @user1.id.to_s, :value => :up)
      Mongoid::Voteable::Tasks.remake_stats
      @post2.reload
    end
    
    it 'validates' do
      @post2.up_votes_count.should == 1
      @post2.down_votes_count.should == 0
      @post2.votes_count.should == 1
      @post2.votes_point.should == 1
      
      @post2.vote_value(@user1.id).should == :up
      @post2.vote_value(@user2.id).should be_nil

      Post.voted_by(@user1).to_a.should == [ @post1, @post2 ]
    end
  end
  

  context 'user1 vote up post2 comment the first time' do
    before :all do
      @comment.vote(:voter_id => @user1.id, :value => :up)
      @comment.reload
      @post2.reload
    end
    
    it 'validates' do
      @post2.up_votes_count.should == 2
      @post2.down_votes_count.should == 0
      @post2.votes_count.should == 2
      @post2.votes_point.should == 3
      
      @comment.up_votes_count.should == 1
      @comment.down_votes_count.should == 0
      @comment.votes_count.should == 1
      @comment.votes_point.should == 1
    end
  end
  
  
  context 'user1 revote post2 comment from up to down' do
    before :all do
      @user1.vote(:votee => @comment, :value => :down)
      @comment.reload
      @post2.reload
    end
    
    it 'validates' do
      @post2.up_votes_count.should == 1
      @post2.down_votes_count.should == 1
      @post2.votes_count.should == 2
      @post2.votes_point.should == 0
      
      @comment.up_votes_count.should == 0
      @comment.down_votes_count.should == 1
      @comment.votes_count.should == 1
      @comment.votes_point.should == -3
    end
    
    it 'revote with wrong value has no effect' do
      @user1.vote(:votee => @comment, :value => :down)
      
      @post2.up_votes_count.should == 1
      @post2.down_votes_count.should == 1
      @post2.votes_count.should == 2
      @post2.votes_point.should == 0
      
      @comment.up_votes_count.should == 0
      @comment.down_votes_count.should == 1
      @comment.votes_count.should == 1
      @comment.votes_point.should == -3
    end
  end
  
  context "user1 unvote on post1" do
    before(:all) do
      @post1.vote(:voter_id => @user1.id, :votee_id => @post1.id, :unvote => true)
      Mongoid::Voteable::Tasks.remake_stats
      @post1.reload
    end
    
    it 'validates' do
      @post1.up_votes_count.should == 0
      @post1.down_votes_count.should == 1
      @post1.votes_count.should == 1
      @post1.votes_point.should == -1
      
      @post1.vote_value(@user1.id).should be_nil
      @post1.vote_value(@user2.id).should == :down
      
      Post.voted_by(@user1).to_a.should_not include(@post1)
    end
  end
  
  context "@post1 has 1 down vote and -1 point, @post2 has 1 up vote, 1 down vote and 0 point" do
    it "verify @post1 counters" do
      @post1.up_votes_count.should == 0
      @post1.down_votes_count.should == 1
      @post1.votes_count.should == 1
      @post1.votes_point.should == -1
    end
    
    it "verify @post2 counters" do
      @post2.up_votes_count.should == 1
      @post2.down_votes_count.should == 1
      @post2.votes_count.should == 2
      @post2.votes_point.should == 0
    end    
  end
  
  context "user1 unvote on comment" do
    before(:all) do
      @user1.unvote(@comment)
      Mongoid::Voteable::Tasks.remake_stats
      @comment.reload
      @post2.reload
    end
    
    it "" do      
      @comment.up_votes_count.should == 0
      @comment.down_votes_count.should == 0
      @comment.votes_count.should == 0
      @comment.votes_point.should == 0

      @post2.up_votes_count.should == 1
      @post2.down_votes_count.should == 0
      @post2.votes_count.should == 1
      @post2.votes_point.should == 1      
    end
  end
  
  context 'final' do
    it "test remake stats" do
      Mongoid::Voteable::Tasks.remake_stats

      @post1.up_votes_count.should == 0
      @post1.down_votes_count.should == 1
      @post1.votes_count.should == 1
      @post1.votes_point.should == -1

      @post2.up_votes_count.should == 1
      @post2.down_votes_count.should == 0
      @post2.votes_count.should == 1
      @post2.votes_point.should == 1
    
      @comment.up_votes_count.should == 0
      @comment.down_votes_count.should == 0
      @comment.votes_count.should == 0
      @comment.votes_point.should == 0    
    end
  end
end
