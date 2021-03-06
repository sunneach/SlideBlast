<h1>SlideBlast.com</h1>

<h2>What is SlideBlast?</h2>
SlideBlast is a realtime, web-based presentation tool built using Erlang, <a href="http://nitrogenproject.com">Nitrogen</a> and <a href="http://riak.basho.com">Riak</a>. It lets you display slides to multiple people through the web, and ensures that all attendees are viewing the same slide. 

<h2>Installation</h2>

* Download and install Ghostscript. <a href="http://pages.cs.wisc.edu/~ghost/">Link</a>
* Download and install Imagemagick. <a href="http://www.imagemagick.org/script/download.php">Link</a>

Then, run the following:

	# Download the SlideBlast code...
	git clone git://github.com/rklophaus/SlideBlast.git
	
	# Download the Riak...
	cd SlideBlast/deps
	hg clone http://bitbucket.org/basho/riak/ 
	
        # Roll back to the compatible version ... 
        hg update -r riak-0.6

	# Compile and start...
	cd ..
	make
	./start.sh
	
	Browse to http://localhost:8000
	
Enjoy!
