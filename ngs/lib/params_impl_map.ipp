/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                                                                                 *
 * ALPS Project: Algorithms and Libraries for Physics Simulations                  *
 *                                                                                 *
 * ALPS Libraries                                                                  *
 *                                                                                 *
 * Copyright (C) 2010 - 2011 by Lukas Gamper <gamperl@gmail.com>                   *
 *                                                                                 *
 * This software is part of the ALPS libraries, published under the ALPS           *
 * Library License; you can use, redistribute it and/or modify it under            *
 * the terms of the license, either version 1 or (at your option) any later        *
 * version.                                                                        *
 *                                                                                 *
 * You should have received a copy of the ALPS Library License along with          *
 * the ALPS Libraries; see the file LICENSE.txt. If not, the license is also       *
 * available from http://alps.comp-phys.org/.                                      *
 *                                                                                 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     *
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,        *
 * FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT       *
 * SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE       *
 * FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,     *
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER     *
 * DEALINGS IN THE SOFTWARE.                                                       *
 *                                                                                 *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef ALPS_NGS_PARAMS_IMPL_MAP_IPP
#define ALPS_NGS_PARAMS_IMPL_MAP_IPP

#include <alps/ngs/hdf5.hpp>
#include <alps/ngs/param.hpp>
#include <alps/ngs/hdf5/map.hpp>
#include <alps/ngs/detail/params_impl_base.hpp>

#include <boost/bind.hpp>

#include <string>

namespace alps {

    namespace detail {

        class params_impl_map : public params_impl_base, std::map<std::string, std::string> {

            public:

                typedef std::map<std::string, std::string> Base;

                params_impl_map() {}

                params_impl_map(hdf5::archive & ar) {
                    std::string context = ar.get_context();
                    ar.set_context("/parameters");
                    load(ar);
                    ar.set_context(context);
                }

                std::size_t size() const {
                    return Base::size();
                }

                std::vector<std::string> keys() const {
                    std::vector<std::string> arr;
                    for (Base::const_iterator it = Base::begin(); it != Base::end(); ++it)
                        arr.push_back(it->first);
                    return arr;
                }

                param operator[](std::string const & key) {
                    return param(
                        boost::bind(&params_impl_map::getter, boost::ref(*this), key),
                        boost::bind(&params_impl_map::setter, boost::ref(*this), key, _1)
                    );
                }

                param const operator[](std::string const & key) const {
                    if (!defined(key))
                        ALPS_NGS_THROW_INVALID_ARGUMENT("unknown argument: "  + key);
                    return param(Base::find(key)->second);
                }

                bool defined(std::string const & key) const {
                    return find(key) != end();
                }

                void save(hdf5::archive & ar) const {
                    ar << make_pvp("", static_cast<Base const &>(*this));
                }

                void load(hdf5::archive & ar) {
                    std::vector<std::string> list = ar.list_children(ar.get_context());
                    for (std::vector<std::string>::const_iterator it = list.begin(); it != list.end(); ++it) {
                        std::string value;
                        ar >> make_pvp(*it, value);
                        insert(std::make_pair(*it, value));
                    }
                }
                
                params_impl_base * clone() {
                    return new params_impl_map(*this);
                }

				#ifdef ALPS_HAVE_MPI
					void broadcast(int root) {
						ALPS_NGS_THROW_LOGIC_ERROR("no communicator available")
					}
				#endif

            private:

                params_impl_map(params_impl_map const & arg)
                    : Base(arg)
                {}

                void setter(std::string key, std::string value) {
                    Base::operator[](key) = value;
                }

                std::string getter(std::string key) {
                    return Base::operator[](key);
                }
        };

    }
}

#endif