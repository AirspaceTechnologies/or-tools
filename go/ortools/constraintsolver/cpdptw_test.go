package constraintsolver

import (
	"fmt"
	"testing"

	"github.com/golang/protobuf/ptypes/duration"
)

type DataModelCPDPTW struct {
	timeMatrix        [][]int64
	timeWindows       [][]int64
	pickupDeliveries  [][]int
	allowedVehicles   [][]int
	vehicleCapacities []int64
	demands           []int
	depot             int
}

////////////////////////////////////////////////////////////////////////////////

func TestConstraintSolver_CPDPTW_Solve(t *testing.T) {
	routing, data, manager, cleanup := setup(t)
	defer cleanup()

	// Setting first solution heuristic.
	searchParameters := DefaultRoutingSearchParameters()
	searchParameters.TimeLimit = &duration.Duration{Seconds: 5}
	searchParameters.SolutionLimit = 100
	searchParameters.FirstSolutionStrategy = FirstSolutionStrategy_PATH_CHEAPEST_ARC
	searchParameters.LocalSearchMetaheuristic = LocalSearchMetaheuristic_GUIDED_LOCAL_SEARCH

	// Asynchronously cancel search.
	// go func() {
	// 	time.Sleep(2 * time.Millisecond)
	// 	routing.CancelSearch()
	// }()

	// Solve the problem.
	solution := routing.SolveWithParameters(searchParameters)

	// Print solution on console.
	printSolutionCPDPTW(t, data, manager, routing, &solution)
}

func TestConstraintSolver_CPDPTW_CheckValidSolution(t *testing.T) {
	routing, data, manager, cleanup := setup(t)
	defer cleanup()

	// Setting first solution heuristic.
	searchParameters := DefaultRoutingSearchParameters()
	searchParameters.TimeLimit = &duration.Duration{Seconds: 5}
	searchParameters.SolutionLimit = 100
	searchParameters.FirstSolutionStrategy = FirstSolutionStrategy_PATH_CHEAPEST_ARC
	searchParameters.LocalSearchMetaheuristic = LocalSearchMetaheuristic_GUIDED_LOCAL_SEARCH

	// close the model
	routing.CloseModelWithParameters(searchParameters)

	// create valid assignment from routes
	routes := [][]int64{
		{12, 1, 4, 3},
		{5, 6, 2, 10},
		{7, 13, 11, 15},
		{9, 8, 14, 16},
	}

	solution := routing.ReadAssignmentFromRoutes(routes, false)
	if routing.GetStatus() != RoutingSearchStatus_ROUTING_SUCCESS {
		t.Errorf("Expected success, got %v", routing.GetStatus())
		return
	}

	// Print solution on console.
	printSolutionCPDPTW(t, data, manager, routing, &solution)
}

func TestConstraintSolver_CPDPTW_CheckInvalidSolution(t *testing.T) {
	routing, _, _, cleanup := setup(t)
	defer cleanup()

	// Setting first solution heuristic.
	searchParameters := DefaultRoutingSearchParameters()
	searchParameters.TimeLimit = &duration.Duration{Seconds: 5}
	searchParameters.SolutionLimit = 100
	searchParameters.FirstSolutionStrategy = FirstSolutionStrategy_PATH_CHEAPEST_ARC
	searchParameters.LocalSearchMetaheuristic = LocalSearchMetaheuristic_GUIDED_LOCAL_SEARCH

	// close the model
	routing.CloseModelWithParameters(searchParameters)

	// create invalid assignment from routes
	routes := [][]int64{
		{12, 16, 4, 3},
		{5, 6, 2, 10},
		{7, 13, 11, 15},
		{9, 8, 14, 1},
	}

	_ = routing.ReadAssignmentFromRoutes(routes, false)
	if routing.GetStatus() != RoutingSearchStatus_ROUTING_FAIL {
		t.Errorf("Expected fail, got %v", routing.GetStatus())
		return
	}
}

////////////////////////////////////////////////////////////////////////////////

func setup(t *testing.T) (RoutingModel, DataModelCPDPTW, RoutingIndexManager, func()) {

	// Solvable pickup deliveries
	solvablePickupDeliveries := [][]int{
		{6, 2},
		{9, 14},
		{5, 10},
	}

	// Allow all vehicles for each pickup/delivery
	allowedVehicles := [][]int{
		{0, 1, 2, 3}, // depot
		{},           // 1
		{0, 1, 2, 3}, // 2
		{},           // 3
		{},           // 4
		{0, 1, 2, 3}, // 5
		{0, 1, 2, 3}, // 6
		{},           // 7
		{},           // 8
		{0, 1, 2, 3}, // 9
		{0, 1, 2, 3}, // 10
		{},           // 11
		{},           // 12
		{},           // 13
		{0, 1, 2, 3}, // 14
		{},           // 15
		{},           // 16
	}

	// Instantiate the data problem.
	data := DataModelCPDPTW{
		timeMatrix:        timeMatrix,
		timeWindows:       timeWindows,
		pickupDeliveries:  solvablePickupDeliveries,
		allowedVehicles:   allowedVehicles,
		vehicleCapacities: []int64{15, 15, 15, 15},
		demands:           []int{0, 0, -1, 0, 0, 1, 1, 0, 0, 1, -1, 0, 0, 0, -1, 0, 0},
		depot:             0,
	}

	// Create Routing Index Manager
	starts := []int{0, 0, 0, 0}
	ends := []int{0, 0, 0, 0}
	manager := NewRoutingIndexManager(len(data.timeMatrix), len(data.vehicleCapacities),
		starts, ends)

	// Create Routing Model.
	routing := NewRoutingModel(manager, DefaultRoutingModelParameters())

	// Allow dropping stops
	penalty := int64(1000)
	for i := 1; i < len(data.timeMatrix); i++ {
		routing.AddDisjunction([]int64{manager.NodeToIndex(i)}, penalty)
	}

	// Create and register a time transit callback.
	f := func(fromIndex, toIndex int64) int64 {
		// Convert from routing variable Index to time matrix NodeIndex.
		fromNode := manager.IndexToNode(fromIndex)
		toNode := manager.IndexToNode(toIndex)
		return data.timeMatrix[fromNode][toNode]
	}
	w := NewGoRoutingTransitCallback2Wrapper(f)
	transitCallbackIndex := routing.RegisterTransitCallback(w.Wrap())

	// Define cost of each arc.
	routing.SetArcCostEvaluatorOfAllVehicles(transitCallbackIndex)

	// Add Time constraint.
	routing.AddDimension(transitCallbackIndex, // transit callback index
		int64(30),  // allow waiting time
		int64(360), // maximum time per vehicle
		false,      // Don't force start cumul to zero
		"Time")
	timeDimension := routing.GetDimensionOrDie("Time")

	// Create and register a capacity transit callback.
	f2 := func(fromIndex int64) int64 {
		// Convert from routing variable Index to time matrix NodeIndex.
		fromNode := manager.IndexToNode(fromIndex)
		return int64(data.demands[fromNode])
	}
	w2 := NewGoRoutingTransitCallback1Wrapper(f2)
	capacityCallbackIndex := routing.RegisterUnaryTransitCallback(w2.Wrap())

	// Add Capacity constraint.
	routing.AddDimensionWithVehicleCapacity(capacityCallbackIndex,
		0,                      // null capacity slack
		data.vehicleCapacities, // vehicle maximum capacities
		true,                   // start cumul to zero
		"Capacity")

	// Add time window constraints for each location except depot and 'copy' the
	// slack var in the solution object (aka Assignment) to print it.
	for i := 1; i < len(data.timeWindows); i++ {
		index := manager.NodeToIndex(i)
		timeDimension.CumulVar(index).SetRange(data.timeWindows[i][0],
			data.timeWindows[i][1])
		routing.AddToAssignment(timeDimension.SlackVar(index))
	}
	// Add time window constraints for each vehicle start node and 'copy' the
	// slack var in the solution object (aka Assignment) to print it.
	// Warning: Slack var is not defined for vehicle end nodes and should not be
	// added to the assignment
	for i := 0; i < len(data.vehicleCapacities); i++ {
		index := routing.Start(i)
		timeDimension.CumulVar(index).SetRange(data.timeWindows[0][0],
			data.timeWindows[0][1])
		routing.AddToAssignment(timeDimension.SlackVar(index))
	}

	// Instantiate route start and end times to produce feasible times.
	for i := 0; i < len(data.vehicleCapacities); i++ {
		routing.AddVariableMinimizedByFinalizer(
			timeDimension.CumulVar(routing.Start(i)))
		routing.AddVariableMinimizedByFinalizer(
			timeDimension.CumulVar(routing.End(i)))
	}

	// Define Transportation Requests.
	solver := routing.Solver()
	for _, request := range data.pickupDeliveries {
		pickupIndex := manager.NodeToIndex(request[0])
		deliveryIndex := manager.NodeToIndex(request[1])
		routing.AddPickupAndDelivery(pickupIndex, deliveryIndex)
		solver.AddConstraint(
			solver.MakeEquality(
				SwigcptrIntExpr(routing.VehicleVar(pickupIndex).Swigcptr()),
				SwigcptrIntExpr(routing.VehicleVar(deliveryIndex).Swigcptr())))
		solver.AddConstraint(
			solver.MakeLessOrEqual(
				SwigcptrIntExpr(timeDimension.CumulVar(pickupIndex).Swigcptr()),
				SwigcptrIntExpr(timeDimension.CumulVar(deliveryIndex).Swigcptr())))
	}

	// Define Allowed Vehicles per node.
	for i := 0; i < len(data.allowedVehicles); i++ {
		// If all vehicles are allowed, do not add any constraint
		if len(data.allowedVehicles[i]) == 0 || len(data.allowedVehicles[i]) == len(data.vehicleCapacities) {
			continue
		}
		nodeIndex := manager.NodeToIndex(i)
		routing.SetAllowedVehiclesForIndex(data.allowedVehicles[i], nodeIndex)
	}

	i := 0                           // Current solution count
	max := 15                        // Max # of solutions
	objectives := make([]int64, max) // Keep track of solution objective costs

	// Define callback function to handle solutions as they are found.
	p := func() {
		o := routing.CostVar().Value()
		if i == 0 || o < objectives[i-1] {
			fmt.Printf("Found Solution! Objective: %v\n", o)
			objectives[i] = o
			printSolutionCPDPTW(t, data, manager, routing, nil)
			i++
		}
		// Stop search after max solutions are found.
		if i >= max {
			routing.Solver().FinishCurrentSearch()
		}
	}
	wp := NewGoAtSolutionCallbackWrapper(p)
	routing.AddAtSolutionCallback(wp.Wrap())

	// wrapper deletion for deferred cleanup
	c := func() {
		wp.Delete()
		w2.Delete()
		w.Delete()
	}

	return routing, data, manager, c
}

////////////////////////////////////////////////////////////////////////////////

// Print the solution.
// data: Data of the problem.
// manager: Index manager used.
// routing: Routing solver used.
func printSolutionCPDPTW(t *testing.T, data DataModelCPDPTW, manager RoutingIndexManager, routing RoutingModel, solution *Assignment) {
	t.Logf("Solver status: %v", routing.GetStatus())

	// Display dropped nodes
	dropped := "Dropped nodes:"
	for n := range routing.Size() {
		if routing.IsStart(n) || routing.IsEnd(n) {
			continue
		}
		if (solution != nil && (*solution).Value(routing.NextVar(n)) == n) ||
			(solution == nil && routing.NextVar(n).Value() == n) {
			dropped += fmt.Sprintf(" %v", manager.IndexToNode(n))
		}
	}
	t.Log(dropped)
	t.Log()

	// Display routes
	timeDimension := routing.GetDimensionOrDie("Time")
	capacityDimension := routing.GetDimensionOrDie("Capacity")
	var totalTime, totalLoad, tMin, tMax, sMin, sMax, capacity int64
	for vehicleId := 0; vehicleId < len(data.vehicleCapacities); vehicleId++ {
		index := routing.Start(vehicleId)
		t.Logf("Route for vehicle %v:", vehicleId)
		var route string
		for !routing.IsEnd(index) {
			timeVar := timeDimension.CumulVar(index)
			slackVar := timeDimension.SlackVar(index)
			capacityVar := capacityDimension.CumulVar(index)
			if solution == nil {
				tMin = timeVar.Min()
				tMax = timeVar.Max()
				sMin = slackVar.Min()
				sMax = slackVar.Max()
				capacity = capacityVar.Value()
			} else {
				tMin = (*solution).Min(timeVar)
				tMax = (*solution).Max(timeVar)
				sMin = (*solution).Min(slackVar)
				sMax = (*solution).Max(slackVar)
				capacity = (*solution).Value(capacityVar)
			}
			route += fmt.Sprintf("%v Time(%v, %v) Slack(%v, %v) Load:%v -> ",
				manager.IndexToNode(index),
				tMin,
				tMax,
				sMin,
				sMax,
				capacity)
			if solution == nil {
				index = routing.NextVar(index).Value()
			} else {
				index = (*solution).Value(routing.NextVar(index))
			}
		}
		timeVar := timeDimension.CumulVar(index)
		capacityVar := capacityDimension.CumulVar(index)
		if solution == nil {
			tMin = timeVar.Min()
			tMax = timeVar.Max()
			capacity = capacityVar.Value()
		} else {
			tMin = (*solution).Min(timeVar)
			tMax = (*solution).Max(timeVar)
			capacity = (*solution).Value(capacityVar)
		}
		t.Logf("%v%v Time(%v, %v) Load:%v\n",
			route,
			manager.IndexToNode(index),
			tMin,
			tMax,
			capacity)
		t.Logf("Time of the route: %vmin\n", tMin)
		t.Logf("Load of the route: %v\n", capacity)
		t.Log()
		totalTime += tMin
		totalLoad += capacity
	}
	t.Logf("Total time of all routes: %vmin\n", totalTime)
	t.Logf("Total load of all routes: %v\n", totalLoad)
	t.Log("Advanced usage:")
	t.Logf("Problem solved in %vms\n", routing.Solver().WallTime())
}
