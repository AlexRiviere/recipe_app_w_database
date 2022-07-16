ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"
require 'bcrypt'
require 'yaml'
require 'pry'

require_relative "../recipe"

class CMSTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown 
    FileUtils.rm_rf(data_path)
  end
  
  def create_recipes_file(name, content= "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def admin_session
    { "rack.session" => {username: "admin"} }
  end
  
  def test_index
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    get '/'
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "feasts"
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
  end
  
  def test_view_category
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    get '/feasts'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "steak"
  end
  
  def test_view_category_no_recipes
    recipe_hash = {"feasts" => ""}
    create_recipes_file("recipes.yml", YAML.dump(recipe_hash))
    get '/feasts'
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "There are no recipes to display."
  end
  
  def test_view_recipe
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    get '/feasts/steak'
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "cook steak"
  end
  
  def test_view_recipe_no_recipe
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    get '/feasts/tacos'
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_includes last_response.body, "That recipe does not exist."
  end
  
  def test_add_recipe
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    post '/add_recipe', {category: "feasts", title: "salmon", ingredients: "salmon, potatoes", instructions: "cook the salmon"}
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_includes last_response.body, "salmon"
  end
  
  def test_add_recipe_with_incomplete_fields
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    post '/add_recipe', {category: "feasts", title: "", ingredients: "salmon, potatoes", instructions: "cook the salmon"}
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Every field needs to be filled in."
  end
  
  def test_add_recipe_to_new_category
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    post '/add_recipe', {category: "seafood", title: "salmon", ingredients: "salmon, potatoes", instructions: "cook the salmon"}
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_includes last_response.body, "salmon"
    assert_includes last_response.body, "seafood"
  end
  
  def test_delete_recipe
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    post '/feasts/steak/delete'
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    refute_includes last_response.body, "steak"
    assert_includes last_response.body, "There are no recipes to display."
  end
  
  def test_edit_recipe
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    post '/feasts/steak/edit', {title: "steak", ingredients: "ribeye, potatoes", instructions: "cook the ribeye steak"}
    
    assert_equal 302, last_response.status
    
    get '/feasts/steak'
    assert_includes last_response.body, "ribeye"
    assert_includes last_response.body, "cook the ribeye"
  end
  
  def test_edit_recipe_with_invalid_input
    recipe_hash = {"feasts" => {"steak" => {"ingredients" => ["steak"], "instructions" => "cook steak"}}}
    create_recipes_file("recipes.yml",  YAML.dump(recipe_hash))
    post '/feasts/steak/edit', {title: "", ingredients: "ribeye, potatoes", instructions: "cook the ribeye steak"}
    
    assert_equal 422, last_response.status
    
    assert_includes last_response.body, "Every field"
  end
end