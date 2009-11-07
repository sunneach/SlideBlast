compile: 
	git submodule update --init
	@(cd ./deps/nitrogen; make)
	@(cd ./deps/riak; make)
	erl -make

css:
	sass ./wwwroot/css/style.sass > ./wwwroot/css/style.css
	
clean:
	rm -rf ./ebin/*.*