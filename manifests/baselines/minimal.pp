# minimal settings, just enough to run puppet

class minimal {

	# networking
	include hosts
	include resolver

	# puppet settings possibly
	include puppet

	# package management possibly

}
