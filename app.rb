class App < Sinatra::Base
	enable :sessions

	get('/register') do
		slim(:register)
	end

	get('/home') do
		slim(:home)
	end

	get('/upload') do
		slim(:upload)
	end
	
	get('/my_profile') do
	end

	get '/' do
		slim(:index) # index.slim
	end


	post('/register') do
		db = SQLite3::Database.new('db/match.sqlite')
		db.results_as_hash = true
		
		username = params["username"]
		password = params["password"]
		password_confirmation = params["confirm_password"]
		
		result = db.execute("SELECT id FROM users WHERE username=?", [username])

		if result.empty?
			if password == password_confirmation
				password_digest = BCrypt::Password.create(password)
				
				db.execute("INSERT INTO users(username, password_digest) VALUES (?,?)", [username, password_digest])
				redirect('/')
			else
				set_error("Passwords don't match")
				redirect('/error')
			end
		else
			set_error("Username already exists")
			redirect('/error')
		end

	end

	post '/login' do # Fångar in formuläret från index.slim 
		db = SQLite3::Database.new("db/match.sqlite") #Länka SQLITE
		username = params["username"] # Hämtad från register.slim, input med name="username"
		password = params["password"]
		password_crypted = db.execute("SELECT password_digest FROM users WHERE username=?", [username])
		if password_crypted == []
			password_digest = nil
		else
			password_crypted = password_crypted[0][0] # första värdet, kollar på username, andra värden är password
			password_digest = BCrypt::Password.new(password_crypted) # "Dekryptar"
		end
		if password_digest == password # om lösenordet matchar
			result = db.execute("SELECT id FROM users WHERE username=?", [username]) #Hämta ID från konton
			session[:id] = result[0][0] # id
			session[:login] = true # Är inloggad
		else
			session[:login] = false # Är INTE inloggad
		end
		redirect('/home')
	end

	post('/upload/style') do

		db = SQLite3::Database.new('db/match.sqlite')
		user_id = session[:user_id].to_i
		@filename = params[:file][:filename]
		image = "../img/#{@filename}"
		puts image
		text = params["note"]

		db.execute("INSERT INTO styles(user_id, image, text) VALUES (?,?,?)", [user_id, image, text])
		
		file = params[:file][:tempfile]
	  
		File.open("./public/img/#{@filename}", 'wb') do |f|
		  f.write(file.read)
		end
		
		slim(:show_image)
	end

	get('/profile') do

		db = SQLite3::Database.new('db/match.sqlite')
		user_id = session[:user_id].to_i
		if session[:login] == true #Om man har loggat in		
			begin
				styles = db.execute('SELECT * FROM styles WHERE user_id = ?', [user_id])
			rescue SQLite3::ConstraintException # Någon anledning kan skapa notes utan att logga in. fixar bugfix
				session[:message] = "You are not logged in"
				redirect("/error")
			end
		else
			session[:message] = "You are not logged in"
			redirect("/error")
		end

		slim(:my_profile, locals:{styles:styles})
	end

	post '/delete/:id' do
		db = SQLite3::Database.new("db/match.sqlite")
		id = params[:id]
		db.execute("DELETE FROM styles WHERE id=?", [id])
		redirect('/profile')
	end

	get('/update/:id') do
		db = SQLite3::Database.new("db/match.sqlite")
		id = params[:id]
		styles = db.execute("SELECT * FROM styles WHERE id=?", [id])
	end

	post('/update/:id') do
		db = SQLite3::Database.new("match.sqlite")
		id = params[:id].to_i
		new_note = params["content"]
		db.execute("UPDATE style SET msg=? WHERE id=?", [new_note, id])
		redirect('/profile')
	end

	get('/error') do
		slim(:error, locals:{msg:session[:message]})
	end

	post('/logout') do
		session[:login] = false
		session[:id] = nil
		redirect('/')
	end
end