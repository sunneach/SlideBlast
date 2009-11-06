compile: 
	git submodule update --init
	make -C ./deps/nitrogen
	erl -make

css:
	sass ./wwwroot/css/style.sass > ./wwwroot/css/style.css
	
clean:
	rm -rf ./ebin/*.*