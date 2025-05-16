// Copyright 2010-2018 Google LLC
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// TODO(user): Refactor this file to adhere to the SWIG style guide.
%include "ortools/base/base.i"
%include "ortools/constraint_solver/go/constraint_solver.i"
%include "ortools/constraint_solver/go/routing_types.i"
%include "ortools/constraint_solver/go/routing_index_manager.i"

// We need to forward-declare the proto here, so that PROTO_INPUT involving it
// works correctly. The order matters very much: this declaration needs to be
// before the %{ #include ".../routing.h" %}.
namespace operations_research {
class RoutingModelParameters;
class RoutingSearchParameters;
class RoutingSearchStatus;
class FloatSlopePiecewiseLinearFunction;
typedef std::function<int64_t(int64_t)> RoutingTransitCallback1;
typedef std::function<int64_t(int64_t, int64_t)> RoutingTransitCallback2;
typedef std::function<const FloatSlopePiecewiseLinearFunction*(int64_t, int64_t)> RoutingCumulDependentTransitCallback2;
typedef std::function<void()> AtSolutionCallback;
}  // namespace operations_research

// Include the files we want to wrap a first time.
%{
#include "ortools/constraint_solver/routing.h"
#include "ortools/constraint_solver/routing_index_manager.h"
#include "ortools/constraint_solver/routing_parameters.h"
#include "ortools/constraint_solver/routing_parameters.pb.h"
#include "ortools/constraint_solver/routing_types.h"
%}

// RoutingModel methods
DEFINE_INDEX_TYPE_TYPEDEF(
    operations_research::RoutingCostClassIndex,
    operations_research::RoutingModel::CostClassIndex);
DEFINE_INDEX_TYPE_TYPEDEF(
    operations_research::RoutingDimensionIndex,
    operations_research::RoutingModel::DimensionIndex);
DEFINE_INDEX_TYPE_TYPEDEF(
    operations_research::RoutingDisjunctionIndex,
    operations_research::RoutingModel::DisjunctionIndex);
DEFINE_INDEX_TYPE_TYPEDEF(
    operations_research::RoutingVehicleClassIndex,
    operations_research::RoutingModel::VehicleClassIndex);

namespace operations_research {

// RoutingModel
%unignore RoutingModel;
%ignore RoutingModel::AddDimensionDependentDimensionWithVehicleCapacity;
%ignore RoutingModel::AddHardTypeIncompatibility;
%ignore RoutingModel::AddMatrixDimension(
    std::vector<std::vector<int64_t> > values,
    int64 capacity,
    bool fix_start_cumul_to_zero,
    const std::string& name);
%ignore RoutingModel::AddSameVehicleRequiredTypeAlternatives;
%ignore RoutingModel::AddTemporalRequiredTypeAlternatives;
%ignore RoutingModel::AddTemporalTypeIncompatibility;
%ignore RoutingModel::CloseVisitTypes;
%ignore RoutingModel::GetAllDimensionNames;
%ignore RoutingModel::GetAutomaticFirstSolutionStrategy;
%ignore RoutingModel::GetDeliveryIndexPairs;
%ignore RoutingModel::GetDimensions;
%ignore RoutingModel::GetDimensionsWithSoftAndSpanCosts;
%ignore RoutingModel::GetDimensionsWithSoftOrSpanCosts;
%ignore RoutingModel::GetGlobalDimensionCumulOptimizers;
%ignore RoutingModel::GetHardTypeIncompatibilitiesOfType;
%ignore RoutingModel::GetLocalDimensionCumulMPOptimizers;
%ignore RoutingModel::GetLocalDimensionCumulOptimizers;
%ignore RoutingModel::GetMutableGlobalCumulOptimizer;
%ignore RoutingModel::GetMutableLocalCumulOptimizer;
%ignore RoutingModel::GetMutableLocalCumulMPOptimizer;
%ignore RoutingModel::GetPerfectBinaryDisjunctions;
%ignore RoutingModel::GetPickupIndexPairs;
%ignore RoutingModel::GetSameVehicleRequiredTypeAlternativesOfType;
%ignore RoutingModel::GetTemporalRequiredTypeAlternativesOfType;
%ignore RoutingModel::GetTemporalTypeIncompatibilitiesOfType;
%ignore RoutingModel::HasHardTypeIncompatibilities;
%ignore RoutingModel::HasSameVehicleTypeRequirements;
%ignore RoutingModel::HasTemporalTypeIncompatibilities;
%ignore RoutingModel::HasTemporalTypeRequirements;
%ignore RoutingModel::HasTypeRegulations;
%ignore RoutingModel::MakeStateDependentTransit;
%ignore RoutingModel::PackCumulsOfOptimizerDimensionsFromAssignment;
%ignore RoutingModel::RegisterStateDependentTransitCallback;
%ignore RoutingModel::RemainingTime;
%ignore RoutingModel::StateDependentTransitCallback;
%ignore RoutingModel::SolveWithParameters(
    const RoutingSearchParameters& search_parameters,
    std::vector<const Assignment*>* solutions);
%extend RoutingModel {
  const Assignment* SolveWithParameters(
      const RoutingSearchParameters& search_parameters) {
        return $self->SolveWithParameters(search_parameters);
      }
}
%ignore RoutingModel::SolveFromAssignmentWithParameters(
      const Assignment* assignment,
      const RoutingSearchParameters& search_parameters,
      std::vector<const Assignment*>* solutions);
%ignore RoutingModel::TransitCallback;
%ignore RoutingModel::UnaryTransitCallbackOrNull;

// RoutingDimension
%unignore RoutingDimension;
%ignore RoutingDimension::GetBreakDistanceDurationOfVehicle;

// TypeRegulationsChecker
%unignore TypeRegulationsChecker;
%ignore TypeRegulationsChecker::CheckVehicle;

}  // namespace operations_research

%rename (v) var;
%rename("GetStatus") operations_research::RoutingModel::status;
%rename("%(camelcase)s", %$isfunction) "";

// Protobuf support
PROTO_INPUT(operations_research::RoutingSearchParameters,
            RoutingSearchParameters,
            search_parameters)
PROTO_INPUT(operations_research::RoutingModelParameters,
            RoutingModelParameters,
            parameters)
PROTO2_RETURN(operations_research::RoutingSearchParameters,
              RoutingSearchParameters)
PROTO2_RETURN(operations_research::RoutingModelParameters,
              RoutingModelParameters)
PROTO_ENUM_RETURN(operations_research::RoutingSearchStatus::Value,
                  RoutingSearchStatus_Value)

// TODO(user): Replace with %ignoreall/%unignoreall
//swiglint: disable include-h-allglobals
%include "ortools/constraint_solver/routing_parameters.h"
%include "ortools/constraint_solver/routing.h"
