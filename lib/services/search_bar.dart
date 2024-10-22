import 'package:flutter/material.dart';

class SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.grey[600]),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => FilterOptions(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FilterOptions extends StatefulWidget {
  @override
  _FilterOptionsState createState() => _FilterOptionsState();
}

class _FilterOptionsState extends State<FilterOptions> {
  RangeValues _priceRange = RangeValues(0, 1000);
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'Name';
  String _location = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter Options', style: Theme.of(context).textTheme.headlineLarge),
          SizedBox(height: 16),
          Text('Price Range'),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000,
            divisions: 20,
            labels: RangeLabels('${_priceRange.start.round()}', '${_priceRange.end.round()}'),
            onChanged: (RangeValues values) {
              setState(() {
                _priceRange = values;
              });
            },
          ),
          SizedBox(height: 16),
          Text('Date Range'),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  child: Text(_startDate == null ? 'Start Date' : '${_startDate!.toLocal()}'.split(' ')[0]),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2025),
                    );
                    if (picked != null && picked != _startDate) {
                      setState(() {
                        _startDate = picked;
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: TextButton(
                  child: Text(_endDate == null ? 'End Date' : '${_endDate!.toLocal()}'.split(' ')[0]),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2025),
                    );
                    if (picked != null && picked != _endDate) {
                      setState(() {
                        _endDate = picked;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text('Sort By'),
          DropdownButton<String>(
            value: _sortBy,
            onChanged: (String? newValue) {
              setState(() {
                _sortBy = newValue!;
              });
            },
            items: <String>['Name', 'Price: Low to High', 'Price: High to Low', 'Date: Newest', 'Date: Oldest']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          Text('Location'),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter location',
            ),
            onChanged: (value) {
              setState(() {
                _location = value;
              });
            },
          ),
          SizedBox(height: 16),
          ElevatedButton(
            child: Text('Apply Filters'),
            onPressed: () {
              // TODO: Implement filter logic
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}