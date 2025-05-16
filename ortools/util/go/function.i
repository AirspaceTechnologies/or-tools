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

%{
  #include <functional>
  #include <iostream>

  #ifndef SWIG_DIRECTORS
  #error "Directors must be enabled in your SWIG module for function.i to work correctly"
  #endif
%}

// Go type corresponding to the given CType
#define GO_TYPE_int64_t int64
#define GO_TYPE_void 
#define GO_TYPE(x) GO_TYPE_ ## x
#define GO_RETURN_int64_t return
#define GO_RETURN_void 
#define GO_RETURN(x) GO_RETURN_ ## x

// These are the things we actually use
#define param(num,type) $typemap(gotype,type) arg ## num
#define unpack(num,type) arg##num
#define lval(num,type) type arg##num
#define lvalgo(num,type) arg##num GO_TYPE(type)
#define lvalref(num,type) type&& arg##num
#define forward(num,type) std::forward<type>(arg##num)

// Mechanics
#define FE_0(...)
#define FE_1(action,a1) action(0,a1)
#define FE_2(action,a1,a2) action(0,a1), action(1,a2)
#define FE_3(action,a1,a2,a3) action(0,a1), action(1,a2), action(2,a3)
#define FE_4(action,a1,a2,a3,a4) action(0,a1), action(1,a2), action(2,a3), action(3,a4)
#define FE_5(action,a1,a2,a3,a4,a5) action(0,a1), action(1,a2), action(2,a3), action(3,a4), action(4,a5)

#define GET_MACRO(_1,_2,_3,_4,_5,NAME,...) NAME
%define FOR_EACH(action,...) GET_MACRO(__VA_ARGS__ __VA_OPT__(,) FE_5, FE_4, FE_3, FE_2, FE_1, FE_0)(action __VA_OPT__(,) __VA_ARGS__) %enddef

// Definition
%define STD_FUNCTION_AS_GO(Name, Ret, ...)

%feature("director") Name##Impl;

%inline %{
  class Name##Impl {
  public:
    virtual ~Name##Impl() {}
    virtual Ret call(__VA_ARGS__) = 0;
  };
%}

%insert(go_header) %{
  type Go##Name##Wrapper interface {
    Name##Impl
    IsGo##Name##Wrapper()
    Delete()
    Wrap() Name
  }

  type go##Name##Wrapper struct {
    Name##Impl
    wrapped Name
  }

  func (g *go##Name##Wrapper) IsGo##Name##Wrapper() {}

  func (g *go##Name##Wrapper) Delete() {
    Delete##Name(g.wrapped)
    g.wrapped = nil
    DeleteDirector##Name##Impl(g.##Name##Impl)
  }

  func (g *go##Name##Wrapper) Wrap() Name {
    return g.wrapped
  }

  type overwrittenMethodsOn##Name##Impl struct {
    i Name##Impl
    goCb func(FOR_EACH(lvalgo __VA_OPT__(,) __VA_ARGS__)) GO_TYPE(Ret)
  }

  func NewGo##Name##Wrapper(goCb func(FOR_EACH(lvalgo __VA_OPT__(,) __VA_ARGS__)) GO_TYPE(Ret)) Go##Name##Wrapper {
    om := &overwrittenMethodsOn##Name##Impl{
      goCb: goCb,
    }
    om.i = NewDirector##Name##Impl(om)

    g := &go##Name##Wrapper{
      Name##Impl: om.i,
    }
    g.wrapped = New##Name(g)

    return g
  }

  // callback implementation
  func (o *overwrittenMethodsOn##Name##Impl) Call(FOR_EACH(lvalgo __VA_OPT__(,) __VA_ARGS__)) GO_TYPE(Ret) {
    GO_RETURN(Ret) o.goCb(FOR_EACH(unpack __VA_OPT__(,) __VA_ARGS__))
  }
%}

%rename(Name) std::function<Ret(__VA_ARGS__)>;
%rename(call) std::function<Ret(__VA_ARGS__)>::operator();

namespace std {
  struct function<Ret(__VA_ARGS__)> {
    // Copy constructor
    function<Ret(__VA_ARGS__)>(const std::function<Ret(__VA_ARGS__)>&);

    // Call operator
    Ret operator()(__VA_ARGS__) const;

    // Conversion constructor from function pointer
    function<Ret(__VA_ARGS__)>(Ret(*const)(__VA_ARGS__));

    %extend {
      function<Ret(__VA_ARGS__)>(Name##Impl *in) {
        return new std::function<Ret(__VA_ARGS__)>([=](FOR_EACH(lvalref __VA_OPT__(,) __VA_ARGS__)){
          return in->call(FOR_EACH(forward __VA_OPT__(,) __VA_ARGS__));
       });
      }
    }
  };
}

%enddef