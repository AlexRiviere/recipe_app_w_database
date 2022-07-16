require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require "sinatra/content_for"
require 'yaml'
require 'bcrypt'
require 'pry'
require 'cgi'

configure do 
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

before do   
  file_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data/recipes.yml", __FILE__)
  else
    File.expand_path("../data/recipes.yml", __FILE__)
  end
  @recipe_hash = YAML.load_file(file_path)
end

def category_exists?(category)
  @recipe_hash.keys.include?(category)
end

def category_empty?(category)
  @recipe_hash[category].empty?
end

def recipe_exists?(category, recipe)
  !!@recipe_hash[category][recipe]
end

def new_recipe_input_valid?(*inputs)
  inputs.all? { |input| !input.strip.empty? }
end

def write_hash_to_file
  file_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data/recipes.yml", __FILE__)
  else
    File.expand_path("../data/recipes.yml", __FILE__)
  end
  File.open(file_path, "w") { |file| file.write(@recipe_hash.to_yaml) }
end

# View the Homepage which is a list of categories
get "/" do
  @categories = @recipe_hash.keys
  erb :index
end

# View the form that allows a user to add a recipe 
get "/add_recipe" do
  erb :add_recipe
end

# Add the recipe
post "/add_recipe" do
  if new_recipe_input_valid?(params[:category], params[:title], params[:ingredients], params[:instructions] )
    single_recipe_hash = {"ingredients" => params[:ingredients].split(","), "instructions" => params[:instructions] }
    if category_exists?(params[:category])
      @recipe_hash[params[:category]][params[:title]] = single_recipe_hash
    else
      @recipe_hash[params[:category]] = {}
      @recipe_hash[params[:category]][params[:title]] = single_recipe_hash
    end
    
    write_hash_to_file
    redirect "/#{params[:category]}"
  else
    session[:message] = "Every field needs to be filled in."
    status 422
    erb :add_recipe
  end
end


# View a category page which is a list of that category's recipes
get "/:category" do |category|
  if category_exists?(category)
    unless category_empty?(category)
      @category_recipes = @recipe_hash[category].keys
    end
  else
    session[:message] = "That category does not exist."
    redirect "/"
  end
  erb :category
end

# view a recipe page 
get "/:category/:recipe" do |category, recipe|
  if category_exists?(category) && recipe_exists?(category, recipe)
    @ingredients = @recipe_hash[category][recipe]["ingredients"]
    @instructions = @recipe_hash[category][recipe]["instructions"]
  else
    session[:message] = "That recipe does not exist."
    redirect "/"
  end
  erb :recipe
end

# Delete a recipe
post '/:category/:recipe/delete' do |category, recipe|
  @recipe_hash[category].delete(recipe)
  write_hash_to_file
  redirect "/#{category}"
end

# Render the edit form for a recipe
get '/:category/:recipe/edit' do |category, recipe|
  erb :edit_recipe
end

# Edit a recipe by deleting it and saving the new recipe
post '/:category/:recipe/edit' do |category, recipe|

  if new_recipe_input_valid?(params[:title], params[:ingredients], params[:instructions] )
    @recipe_hash[category].delete(recipe)
    single_recipe_hash = {"ingredients" => params[:ingredients].split(",").map(&:to_s), "instructions" => params[:instructions] }
    @recipe_hash[params[:category]][params[:title]] = single_recipe_hash
    write_hash_to_file
    redirect "/#{category}"
  else
    session[:message] = "Every field needs to be filled in."
    status 422
    erb :edit_recipe
  end
end