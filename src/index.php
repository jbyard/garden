<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
<html lang='en'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Garden</title>
	<link rel='stylesheet' href='garden.css'>
</head>
<body>

<!-- BEGIN container -->
<div class='container'>

<h1><a href='index.php'>Garden Activity</a></h1>

<!-- BEGIN graph -->
<div class='item' id='graph'>
<div class='table'>
	<div class='row'>
	 <div class='cell'></div>
<?php

	require_once('.env.php');

	$dbconn = pg_connect("host=database dbname=".PGDATABASE." user=".PGUSER." password=".PGPASSWORD)
			or die('Could not connect: ' . pg_last_error());

	$query = "
		SELECT
			rn, contributions, date, class, label, details
		FROM garden.contributions
		";
	$result = pg_query($query) or die('Query failed: ' . pg_last_error());

	$last_row = 0;

	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {

		# Y-axis labels
		if ($row["rn"] > $last_row) {
			$row_html = "\n\t</div>\n\t<div class='row'>\n\r\r<div class='cell'>";

			switch ($row["rn"]) {
				case 2:
					$row_html .= "M";
					break;
				case 4:
					$row_html .= "W";
					break;
				case 6:
					$row_html .= "F";
					break;
			}

			$row_html .= "</div>";

			echo $row_html;
			$last_row = $row["rn"];
		}

		$contribute_string = '';
		if (isset($row["contributions"])) {
			$contribute_string = $row["contributions"] == 0 ?
				"No contributions" : $row["contributions"]." contributions";
		}

		$selected = '';
		if (isset($row["date"]) && isset($_GET["date"])
			&& $row["date"] == $_GET["date"]
			) {
			$selected = 'selected';
		}

		$cell_html = "<a class='cell ".$row["class"]." ".$selected."' ";

		if(isset($row["date"])) {
			$cell_html .= " href='index.php?date=".$row["date"]."' ";
		}

		$cell_html .= $row["details"] ? " title='".$contribute_string." ".$row["details"]."'" : "";
		$cell_html .= ">".$row["label"]."</a>";

		echo $cell_html;
	}
	pg_free_result($result);

?>
	</div>
</div>
</div>
<!-- END graph -->


<!-- BEGIN log -->
<div class='item' id='log'>
<ul>
<?php

	$selected = $previous = $next = NULL;

	$query = "
		SELECT previous, selected, next
		FROM garden.date_nav(COALESCE($1,NOW()::date))
		";

	$result = pg_prepare($dbconn, 'date_nav', $query)
		or die('Query prepare failed: ' . pg_last_error());

	$result = pg_execute($dbconn, 'date_nav', array($_GET["date"]))
		or die('Query execute failed: ' . pg_last_error());

	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
		$selected   = $row["selected"];
		$previous   = $row["previous"];
		$next       = $row["next"];
	}


	$title_html = '<h2>';
	$title_html .= isset($previous) ? "<a href='index.php?date=$previous'><  </a>" : '';
	$title_html .= $selected;
	$title_html .= isset($next) ? "<a href='index.php?date=$next'>  ></a>" : '';
	$title_html .= '</h2>';
	echo $title_html;

	$query = "
		SELECT date, action
		FROM garden.log
		WHERE ts::date = COALESCE($1,NOW()::date)
		";

	$result = pg_prepare($dbconn, 'get_log', $query)
		or die('Query prepare failed: ' . pg_last_error());

	$result = pg_execute($dbconn, 'get_log', array($_GET["date"]))
		or die('Query execute failed: ' . pg_last_error());

	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	    echo "\t<li>".$row["action"]."</li>\n";
	}
	pg_free_result($result);
?>
</ul>
</div>
<!-- END log -->


<!-- BEGIN update -->
<div class='item' id='update'>
<form action='update.php' method='post'>
<h2>Update Log</h2>

<?php

	$radio_html = '';
	if (isset($_GET["date"])) {

		$radio_html .= "<input name='date' id='selected' type='radio' value='".$_GET["date"]."' checked='checked'>\n";
		$radio_html .= "<label for='selected'>".$_GET["date"]."</label>\n";

		$radio_html .= "<input name='date' id='today' type='radio' value='".date('Y/m/d').">\n";

	} else {

		$radio_html .= "<input name='date' id='today' type='radio' value='".date('Y/m/d')."' checked='checked'>\n";
	}

	$radio_html .= "<label for='today'>Today</label>\n";

	echo $radio_html;
?>

<div>
<label for='action' accesskey='a'>Action</label>
<select name='action' id='action'>
<option selected='selected' value=''>-- none --</option>
<?php
	$query = "SELECT action, label FROM garden.actions";
	$result = pg_query($query) or die('Query failed: ' . pg_last_error());

	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	    echo "\t<option value='".$row["label"]."'>".$row["label"]."</option>\n";
	}
	pg_free_result($result);
?>
</select>
</div>

<div>
<label for='quantity' accesskey='q'>Quantity</label>
<input name='quantity' id='quantity' type='number' min='0' max='256'>
</div>

<div>
<label for='weight' accesskey='w'>Weight ounces</label>
<input name='weight' id='weight' type='number' min='0' max='1600'>
</div>

<div>
<label for='variety' accesskey='v'>Variety</label>
<input name='variety' id='variety' type='text'></br>
</div>

<div>
<label for='plant' accesskey='p'>Plant</label>
<select name='plant'>
<option selected='selected' value=''>-- none --</option>
<?php
	$query = "SELECT plant, label FROM garden.plants ORDER BY label";
	$result = pg_query($query) or die('Query failed: ' . pg_last_error());

	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	    echo "\t<option value='".$row["label"]."'>".$row["label"]."</option>\n";
	}
	pg_free_result($result);
?>
</select>
</div>


<div>
<label for='bed' accesskey='b'>Bed</label>
<select name='bed'>
<option selected='selected' value=''>-- none --</option>
<?php
	$query = "SELECT bed, label FROM garden.beds ORDER BY label";
	$result = pg_query($query) or die('Query failed: ' . pg_last_error());

	while ($row = pg_fetch_array($result, null, PGSQL_ASSOC)) {
	    echo "\t<option value='".$row["label"]."'>".$row["label"]."</option>\n";
	}
	pg_free_result($result);
?>
</select>
</div>

<div>
<input name='submit' type='submit' value='save'></input>
<input name='cancel' type='submit' value='cancel'></input>
</div>

</form>
</div>
<!-- END update -->


<?php pg_close($dbconn); ?>

<!-- END container -->
</div>

</body>
</html>
