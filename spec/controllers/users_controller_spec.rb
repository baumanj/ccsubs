require 'controllers/shared'

describe UsersController do

  describe "GET 'new'" do
    it_behaves_like "an action needing admin"
  end

end
