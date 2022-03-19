<?php

require_once('.env.php');

$dbconn = pg_connect("host=localhost dbname=".PGDATABASE." user=".PGUSER." password=".PGPASSWORD)
		or die('Could not connect: ' . pg_last_error());

$action = $plant = $bed = NULL;


if (isset($_POST['action']))     $action     = $_POST['action'];
if (isset($_POST['bed']))        $bed        = $_POST['bed'];
if (isset($_POST['date']))       $date       = $_POST['date'];
if (isset($_POST['plant']))      $plant      = $_POST['plant'];
if (isset($_POST['quantity']))   $quantity   = $_POST['quantity'];
if (isset($_POST['variety']))    $variety    = $_POST['variety'];

if ($action == '') die('An action is required');
if ($date == '') die('A date is required');
if ($plant == '') die('A plant is required');

$query = "
	SELECT garden.add_entry(jsonb_build_object(
		'action',     $1::TEXT,
		'bed',        $2::TEXT,
		'plant',      $3::TEXT,
		'quantity',   $4::TEXT,
		'variety',    $5::TEXT
	),$6::TIMESTAMPTZ)
	";
$result = pg_prepare($dbconn, 'log_entry', $query) or die('Query prepare failed: ' . pg_last_error());
$result = pg_execute($dbconn, 'log_entry', array(
	$action, $bed, $plant, $quantity, $variety, $date
	)) or die('Query execute failed: ' . pg_last_error());

pg_close($dbconn);

header("Location:index.php?date=$date");
?>
