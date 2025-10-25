import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import './ProjectPage.css';
import {showErrorToast, showSuccessToast} from "./ProjectTostify";

const ProjectPage = () => {
  const url = `${process.env.REACT_APP_BACKEND_URL}`
  const [projects, setProjects] = useState([]);

    useEffect(() => {
    const fetchProjects = async () => {
      try {
        const response = await axios.get(`${url}/projects`);
        setProjects(response.data);
      } catch (error) {
        console.error('Error fetching projects:', error);
      }
    };
    fetchProjects();
  }, []);

  const handleDelete = async (id) => {
    try {
      await axios.delete(`${url}/projects/${id}`);
      showSuccessToast(`Project with id: ${id} was deleted`);
      setProjects((prevProjects) => prevProjects.filter((project) => project.id !== id));
    } catch (error) {
      showErrorToast(`Project with id: ${id} was not deleted`);
      console.error(`Error deleting project with id ${id}:`, error);
    }
  };

    return (
      <div>
      <h1>List of Projects</h1>
        <Link to="/projects/create">
          <button>Create project</button>
        </Link>
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>description</th>
            <th>Editing</th>
            <th>Delete</th>
          </tr>
        </thead>
        <tbody>
          {projects.map((project) => (
            <tr key={project.id}>
              <td>{project.id}</td>
              <td>{project.name}</td>
              <td>{project.description}</td>
              <td>
                <Link to={`/projects/${project.id}/edit`}>
                  <button>Edit</button>
                </Link>
              </td>
              <td>
                <button onClick={() => handleDelete(project.id)}>Del</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
    );
};

export default ProjectPage;
