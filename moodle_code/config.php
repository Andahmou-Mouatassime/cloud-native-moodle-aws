<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('DB_HOST');
$CFG->dbname    = getenv('DB_NAME');
$CFG->dbuser    = getenv('DB_USER');
$CFG->dbpass    = getenv('DB_PASS');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 3306,
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_general_ci',
);

// Détection automatique de l'URL du Load Balancer AWS
if (isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $CFG->wwwroot = 'http://' . $_SERVER['HTTP_X_FORWARDED_HOST'];
} elseif (isset($_SERVER['HTTP_HOST'])) {
    $CFG->wwwroot = 'http://' . $_SERVER['HTTP_HOST'];
} else {
    $CFG->wwwroot = 'http://localhost'; // Fallback pour les commandes CLI
}

$CFG->dirroot  = '/var/www/html';
$CFG->libdir   = '/var/www/html/lib'; // Ligne à ajouter
$CFG->dataroot = '/var/www/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0777;

// Configuration des sessions via Redis (Désactivée temporairement)
//$CFG->session_handler_class = '\core\session\redis';
//$CFG->session_redis_host = 'redis';
//$CFG->session_redis_port = 6379;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
